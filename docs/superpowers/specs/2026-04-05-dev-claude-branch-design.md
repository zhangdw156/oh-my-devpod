# `dev/claude` Long-Lived Branch Design

## Summary

This design defines a long-lived `dev/claude` branch that replaces the current OpenCode runtime with Claude Code while preserving the core openpod experience:

- container-first and bootstrap-first developer environments
- vendored shell/editor/runtime assets
- optional `.env`-driven non-interactive setup
- fallback to user-managed `claude login` or manual Claude configuration

The branch is treated as a parallel product line, not an experiment. The public image name becomes `oh-my-claudepod`, and the user-facing runtime semantics move from OpenCode to Claude Code.

## Goals

- Maintain a dedicated `dev/claude` branch for long-term use.
- Replace OpenCode with Claude Code in both Docker and bootstrap flows.
- Preserve the current "openpod-like" workflow: build image, mount project, start shell, begin AI-assisted work quickly.
- Support two authentication paths:
  - `.env` exists: prefer environment-driven setup and materialize Claude configuration automatically.
  - `.env` does not exist: let users rely on `claude login` or hand-maintained Claude config.
- Rename user-facing image artifacts to carry Claude semantics, using `oh-my-claudepod`.
- Keep compatibility only where it reduces migration friction without keeping old OpenCode concepts alive.

## Non-Goals

- Supporting existing OpenAI-compatible provider wiring from the OpenCode branch.
- Preserving `opencode.json`, `~/.config/opencode`, or OpenCode plugin semantics on `dev/claude`.
- Building a single branch that can switch at runtime between OpenCode and Claude Code.
- Renaming the repository itself in this design pass.

## Current State

The current repository is deeply coupled to OpenCode in five places:

1. Docker image build installs `opencode` and wires `/root/.config/opencode/...`.
2. Bootstrap mode installs `opencode`, writes OpenCode config, and links vendored OpenCode plugin assets.
3. Documentation and smoke tests use `opencode` commands and `opencode.json`.
4. Vendored runtime assets include OpenCode-specific package layout under `vendor/opencode/...`.
5. The user mental model is explicitly "OpenCode + uv + Git + Zsh".

This is more than a binary replacement. The branch must shift installation, config layout, runtime sync, vendor layout, docs, and verification commands together.

## Approaches Considered

### Approach 1: Dedicated Claude Product Branch

Create `dev/claude` as a long-lived branch that fully switches user-facing AI runtime semantics from OpenCode to Claude Code while preserving the surrounding shell/editor/container experience.

Pros:

- clean public semantics
- easiest long-term maintenance model for a parallel release line
- avoids hybrid docs and hybrid config behavior

Cons:

- sustained diff versus `main`
- requires migration of docs and vendor layout

### Approach 2: Compatibility-Layer Branch

Keep most openpod/OpenCode language and layout, but swap the backend CLI to Claude Code and add adapters.

Pros:

- lower short-term migration cost

Cons:

- mixes Claude runtime with OpenCode-era concepts
- harder documentation and debugging
- long-term maintenance becomes muddy

### Approach 3: Runtime-Parameterized Single Codebase

Refactor the repository so one codebase can produce either OpenCode or Claude variants through switches or branch defaults.

Pros:

- more code reuse

Cons:

- highest implementation complexity
- not justified for the stated goal of maintaining a dedicated Claude branch

### Recommendation

Use Approach 1. `dev/claude` becomes a clear, dedicated Claude Code product line while keeping the broader openpod ergonomics and shared non-AI infrastructure.

## Branch Positioning And Naming

- Branch name: `dev/claude`
- Public image name family: `oh-my-claudepod:*`
- GHCR image name family: `ghcr.io/zhangdw156/oh-my-claudepod:*`
- Default container/service name: `claudepod`

The repository name may remain `oh-my-openpod`, but documentation, image names, container examples, and runtime descriptions in this branch should adopt Claude-oriented naming.

## Runtime And Configuration Model

### Claude Runtime

Both Docker and bootstrap flows install Claude Code using the official native Linux install path, not the deprecated npm path.

### Authentication Modes

Two authentication modes must coexist:

1. `.env`-driven mode
2. user-managed mode

#### `.env`-driven mode

If relevant Claude environment variables are present, the runtime must prefer them and synchronize managed settings for Claude Code automatically.

Supported configuration surface in this branch is limited to Claude Code official integration paths:

- Anthropic direct auth
- Anthropic-compatible gateway / base URL variants supported by Claude Code
- Amazon Bedrock
- Google Vertex AI
- Microsoft Foundry

OpenAI-compatible provider support is intentionally dropped from this branch.

#### User-managed mode

If `.env` is absent, the runtime must not fabricate auth config. Users may:

- run `claude login`
- maintain `~/.claude/settings.json` manually
- maintain project-local `.claude/settings.json` or `.claude/settings.local.json`

### Managed Sync Layer

Add a dedicated sync step, conceptually named `claudepod-sync-config`.

Responsibilities:

- inspect current environment before `claude` execution
- merge branch-managed settings into `~/.claude/settings.json`
- track which keys were written by claudepod
- remove only claudepod-managed keys when `.env`-driven config disappears

This sync must be idempotent.

It must not overwrite unrelated user settings. To make rollback safe, the branch should maintain a separate state file such as:

- `~/.claude/oh-my-claudepod-state.json`

The state file records which settings keys are managed by claudepod so that later sync runs can remove only those keys.

### Config Ownership Rules

Claudepod manages only runtime/connection settings that come from environment-driven setup.

Users remain free to manage other Claude preferences in `~/.claude/settings.json`, such as:

- permissions
- UI preferences
- hooks not owned by claudepod
- personal defaults unrelated to environment-provided auth/endpoints

### Config Precedence Consideration

This branch must explicitly respect Claude Code's config precedence:

- user-level settings are lower precedence than project-local settings
- environment-provided auth can outrank interactive login state

Therefore the branch should avoid blunt full-file replacement and should document that project-level `.claude/` config can intentionally override user-level defaults.

## Repository Layout Changes

### Config Templates

Replace the OpenCode-specific default config template with a Claude-oriented base template, for example:

- `config/claude/settings.base.json`

This file contains only non-secret baseline settings. Secrets and auth-related values are injected at runtime by the sync layer.

### Vendor Layout

The branch should move AI-specific vendored assets away from `vendor/opencode/...` and adopt Claude semantics:

- `vendor/claude/skills/`

This becomes the single skills exposure root for Claude Code in `dev/claude`.

### Superpowers Assets

The current vendored OpenCode plugin wrapper under:

- `vendor/opencode/packages/superpowers/.opencode/plugins/...`

is not useful for Claude Code and should not be retained as a living interface in this branch.

However, the upstream `superpowers` skills content remains useful. The branch should vendor the `skills/` subtree from upstream `obra/superpowers` into:

- `vendor/claude/skills/superpowers/`

Repository-maintained supplemental skills should live separately, for example:

- `vendor/claude/skills/oh-my-claudepod/`

This keeps a clean separation between upstream-vendored skills and local project skills.

### Manifest And Asset Docs

`vendor/manifest.lock.json` and `docs/vendor-assets.md` must be rewritten to describe Claude-oriented assets, including:

- Claude Code install source
- vendored `superpowers` skills snapshot source/version
- local `vendor/claude/skills/...` paths

## User-Facing Entry Points

### Shell Entrypoints

Introduce:

- `claudepod-shell` as the primary documented shell entrypoint

Keep:

- `openpod-shell` as a compatibility alias only

The compatibility alias exists to reduce migration friction, but docs on this branch should treat `claudepod-shell` as canonical.

### Command Execution Flow

Before interactive Claude usage, the branch should route through the sync layer:

1. start shell or wrapper
2. run `claudepod-sync-config`
3. execute the real `claude`

This behavior should cover:

- container startup path
- `claudepod-shell`
- compatibility `openpod-shell`
- optional direct wrapper invocation for `claude`

### Compose And Container Names

`docker-compose.yml` should use Claude-oriented names:

- service name: `claudepod`
- container name: `claudepod`

This branch should stop using `openpod` as the primary visible runtime name.

## Docker Design

Docker changes include:

- install Claude Code instead of OpenCode
- write Claude-oriented config under `/root/.claude/`
- expose `vendor/claude/skills` to `/root/.claude/skills`
- include wrapper/sync scripts in the image
- preserve existing non-AI tooling such as uv, Neovim, Zsh, Yazi, btop, and Zellij

The image must not bake secrets. `.env` continues to be runtime input via Compose or `docker run --env-file`.

## Bootstrap Design

Bootstrap changes include:

- install Claude Code instead of OpenCode
- use Claude-oriented config home
- link vendored skills into `~/.claude/skills`
- install `claudepod-shell` and compatibility `openpod-shell`
- source env and invoke sync before shell entry

Bootstrap should continue to avoid mutating the user's existing `~/.zshrc`.

## Documentation Changes

`README.md` and `README_EN.md` must be rewritten so this branch documents:

- Claude Code as the AI runtime
- `.claude/settings.json` and `CLAUDE.md` as the project/user config model
- `oh-my-claudepod` image names
- `claudepod-shell` as the primary shell entrypoint
- `claude --version` and `claude doctor` as smoke tests

Documentation should also include a migration note explaining that `dev/claude` does not use:

- `opencode.json`
- `~/.config/opencode`
- OpenCode plugin directories

## Verification Strategy

Verification is split into three layers.

### 1. Installation Verification

Confirm Claude Code binary presence and health:

- `claude --version`
- `claude doctor`

### 2. Config Sync Verification

Cover both paths:

- with `.env`
- without `.env`

Required assertions:

- sync is idempotent
- managed keys are written correctly when env is present
- managed keys are removed when env disappears
- unrelated user settings survive sync
- existing login-based or user-managed config is not destroyed

### 3. Runtime Verification

When authentication is available, run a minimal non-interactive prompt call, such as a trivial `claude -p` request.

Because this requires valid credentials, docs should separate:

- runtime installed correctly
- runtime authenticated correctly

## Migration Guidance

This branch should include explicit guidance for users moving from the OpenCode line:

- image name changes to `oh-my-claudepod`
- project config moves from `opencode.json` to `.claude/settings.json` and `CLAUDE.md`
- global config moves from `~/.config/opencode/...` to `~/.claude/...`
- OpenCode plugins are no longer part of the runtime model

Compatibility is intentionally limited to shell entrypoint aliasing, not to legacy config semantics.

## Long-Term Maintenance Strategy

Treat `main` and `dev/claude` as parallel product lines:

- `main` remains OpenCode-oriented
- `dev/claude` becomes Claude Code-oriented

Shared non-AI infrastructure should continue to be cherry-picked or merged across branches where appropriate:

- shell assets
- Neovim assets
- uv and Python tooling
- terminal tools
- generic installer scripts

AI-runtime-specific files are expected to diverge.

## Risks

### Claude Code Configuration Drift

Claude Code official config semantics may evolve. The branch needs clear asset provenance and docs so maintainers can update config sync behavior safely.

### Upstream Superpowers Layout Changes

The upstream repository may change how skills are organized. Vendor metadata and docs must record the exact upstream snapshot and intended extraction path.

### Hybrid Terminology Regression

If old OpenCode terms remain in docs or file layout, the branch will become harder to use and maintain. The migration should be intentionally opinionated about removing old user-facing config concepts.

## Implementation Boundaries

The first implementation plan for this design should cover:

- Claude runtime installation changes in Docker and bootstrap
- sync/wrapper scripts
- vendor layout transition for Claude skills
- manifest/docs updates
- README and smoke-test command rewrite

It should not attempt unrelated refactors to shared shell/editor infrastructure.

## Source Notes

This design is based on the current repository layout plus Claude Code official documentation covering setup, authentication, environment variables, settings precedence, and supported cloud/provider integration surfaces.
