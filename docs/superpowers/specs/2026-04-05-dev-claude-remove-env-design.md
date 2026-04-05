# `dev/claude` Remove `.env` Authentication Design

## Summary

This design removes the `.env`-driven authentication mechanism from the long-lived `dev/claude` branch and returns the branch to a pure Claude-native configuration model.

After this change:

- Docker mode no longer consumes `.env`
- bootstrap mode no longer consumes `.env`
- the runtime no longer materializes managed auth keys into `~/.claude/settings.json`
- users authenticate or configure Claude Code themselves through native Claude workflows

The goal is not to add new capability. The goal is to remove an adaptation layer that makes the branch harder to reason about.

## Goals

- Remove `.env` as a supported runtime configuration mechanism on `dev/claude`
- Eliminate automatic auth/config materialization into `~/.claude/settings.json`
- Make Docker, bootstrap, docs, and tests all match the same model
- Keep Claude Code installation, shell wrappers, vendored skills, and non-AI tooling intact

## Non-Goals

- Reworking Claude Code installation
- Changing vendored skill layout under `vendor/claude/skills`
- Renaming the branch, image, or container again
- Adding any replacement secret-management layer

## Current Problem

The branch currently mixes two mental models:

1. Claude-native configuration through `claude auth login`, `~/.claude/settings.json`, and project-local `.claude/`
2. Repository-managed `.env` ingestion plus `claudepod-sync-config`

That hybrid behavior causes confusion:

- users cannot easily predict whether auth came from login state or generated settings
- Docker and bootstrap behavior become harder to explain
- documentation needs exceptions and fallback explanations
- the runtime owns authentication behavior that should belong to the user

The most coherent fix is to remove the `.env` layer entirely.

## Approaches Considered

### Approach 1: Keep `.env`, improve docs

Pros:

- preserves convenience for some users

Cons:

- leaves the mixed mental model intact
- keeps special-case runtime behavior
- does not solve the core design issue

### Approach 2: Keep `.env`, but stop documenting it prominently

Pros:

- smaller visible surface change

Cons:

- behavior still exists
- hidden behavior is worse than documented behavior
- future maintainers still inherit the ambiguity

### Approach 3: Remove `.env` completely

Pros:

- clean runtime semantics
- easier docs
- easier debugging
- aligns with Claude Code's native model

Cons:

- first-run authentication becomes more manual

### Recommendation

Use Approach 3. The branch should explicitly require users to configure Claude themselves.

## Runtime Model After Change

The branch should support only Claude-native authentication and configuration paths:

- `claude auth login`
- user-managed `~/.claude/settings.json`
- project-local `.claude/settings.json`
- project-local `.claude/settings.local.json`
- `CLAUDE.md`

The runtime should not read `.env`, should not generate auth settings, and should not manage a Claude config state file for credentials.

## Repository Changes

### Remove `.env` Runtime Support

Remove:

- `.env.example`
- `docker-compose.yml` `env_file` wiring
- `.env` references in README and README_EN
- `.env` behavior from tests

### Remove Sync Layer

Delete:

- `bin/claudepod-sync-config`

Simplify:

- `bin/claude` so it directly executes the real Claude binary
- bootstrap environment exports so they no longer mention `OPENPOD_SOURCE_REPO` or `OPENPOD_CLAUDE_SYNC_BIN`

### Keep Base Settings, Drop Managed Auth

`config/claude/settings.base.json` may remain if it only contains harmless non-secret defaults such as permission mode.

What changes is ownership:

- the repository may still ship a baseline Claude settings template
- the repository no longer owns authentication data or runtime credential injection

## Documentation Changes

README and README_EN should change from:

- ".env is optional or recommended"
- "claudepod will read /workspace/.env"
- "Docker mode injects .env"

to:

- "authenticate with `claude auth login`"
- "or mount/manage your own `~/.claude`"
- "or configure project-local `.claude/settings.json` yourself"

The branch should explicitly say that `.env` is not part of the runtime model.

## Testing Changes

Remove tests that prove `.env` ingestion behavior.

Keep tests that still matter:

- Claude wrapper execution
- install helpers
- bootstrap shell wiring
- existing Neovim/LazyVim/tooling smoke tests

Add or keep verification proving the negative behavior:

- no generated managed auth state file
- no runtime dependency on `.env`

## Risks

### Less Convenience For First Run

Users lose automatic auth injection, so initial setup becomes more manual.

This is an intentional tradeoff in favor of consistency and transparency.

### Stale Docs Or Helper Paths

Because `.env` currently appears in Docker, bootstrap, tests, and docs, the main implementation risk is missing one of those references and leaving the branch in a half-removed state.

## Implementation Boundary

The implementation plan for this design should cover:

- removing `.env` artifacts and wiring
- removing the sync script
- simplifying wrappers and bootstrap exports
- rewriting docs to user-managed Claude config
- updating tests to reflect the new model

It should not revisit unrelated runtime naming or Claude installation behavior.
