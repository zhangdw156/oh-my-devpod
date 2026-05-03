# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Repository purpose

`oh-my-devpod` builds a shared `devpod` base plus five thin runtime flavors:

- `openpod` for OpenCode
- `claudepod` for Claude Code
- `codexpod` for Codex
- `copilotpod` for GitHub Copilot CLI
- `geminipod` for Gemini CLI

The repository vendors shared shell/editor/build assets under `vendor/`, and the `openpod` flavor owns its OpenCode-specific vendored assets under `runtime/openpod/vendor/opencode/`.

## Core development commands

### Run the flavors

Compose files default to pulling official images from GHCR:

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" codexpod -lc 'codex --help | sed -n "1,20p"'
docker compose -f docker/copilotpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" copilotpod -lc 'copilot --version'
docker compose -f docker/geminipod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" geminipod -lc 'gemini --version'
```

### Refresh vendored assets

```bash
bash build/update-vendor-assets.sh
```

After refreshing vendored assets, rebuild the affected flavors and rerun the smoke commands above.

### Superpowers plugin tests

The repository vendors the full `obra/superpowers` package inside the `openpod` runtime tree.

```bash
bash runtime/openpod/vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh
bash runtime/openpod/vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh --test test-plugin-loading.sh
bash runtime/openpod/vendor/opencode/packages/superpowers/tests/opencode/test-plugin-loading.sh
bash runtime/openpod/vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh --integration
```

## Release and versioning

- The single source of truth for image and release versions is the root `VERSION` file.
- The single source of truth for tool versions (atuin, btop, neovim, etc.) is `versions.env`. Build scripts source it; Dockerfiles declare matching ARG defaults; install scripts use env var fallbacks. Run `bash tests/test-versions-env.sh` to verify consistency.
- Pod-local compose files stay the local runtime contract for each flavor and pull from `ghcr.io/zhangdw156/{flavor}:${IMAGE_VERSION:-latest}`; they do not read `VERSION` automatically.
- `.github/workflows/publish-ghcr.yml` reads `VERSION` directly.
- Releases go through PRs with `gh pr merge --squash --delete-branch` to keep a clean branch history. The release machine has `gh` available.
- Do not create release or version-bump commits directly on main; always use a PR.

Release flow details live in `DEVELOPMENT.md`.

## High-level architecture

### 1. Shared base plus flavor runtimes

- `Dockerfile.devpod` and `build/` own shared shell, editor, Python, and terminal tooling
- `docker/openpod/Dockerfile`, `docker/claudepod/Dockerfile`, `docker/codexpod/Dockerfile`, `docker/copilotpod/Dockerfile`, and `docker/geminipod/Dockerfile` only add harness-specific layers
- `runtime/<flavor>/` owns harness-specific launchers, config, installers, skills, and any flavor-specific vendored assets

### 2. Pod-local compose files are the local runtime contract

Each `docker/<flavor>/docker-compose.yaml` file defines the canonical local workflow for that flavor and defaults to pulling the official image from `ghcr.io/zhangdw156/{flavor}:latest`. A commented-out `build:` section is available for users who want to build locally. Compose renders image tags through `${IMAGE_VERSION:-latest}` and does not read `VERSION` automatically.

### 3. Vendoring is split by ownership

Shared vendored assets live under:

- `vendor/releases/`
- `vendor/zsh/`
- `vendor/nvim/`

OpenCode-specific vendored assets live under:

- `runtime/openpod/vendor/opencode/packages/`
- `runtime/openpod/vendor/opencode/skills/`

`build/update-vendor-assets.sh` refreshes both the shared vendor roots and the `openpod` OpenCode snapshot, then syncs `superpowers` skills into the Claude, Codex, Copilot, and Gemini runtime trees.

### 4. OpenCode plugin layout must stay intact

`superpowers` is not just a folder of `SKILL.md` files. Its OpenCode entrypoint lives at `.opencode/plugins/superpowers.js` and resolves `../../skills` relative to that file. Because of that:

- keep the package root intact under `runtime/openpod/vendor/opencode/packages/superpowers`
- keep repo-managed OpenCode global skills under `runtime/openpod/vendor/opencode/skills`
- keep the baked default OpenCode config under `runtime/openpod/config/opencode.json`
- do not manually add `superpowers/skills` to OpenCode `skills.paths`; the plugin registers its own bundled skills at runtime

### 5. Documentation is split by audience

- `README.md` / `README_EN.md`: user-facing usage
- `DEVELOPMENT.md`: maintainer rules such as versioning, releases, and asset ownership
- `docs/vendor-assets.md`: authoritative explanation of vendored assets and refresh workflow
- `docs/environment-variables.md`: complete reference for all `OHMYDEVPOD_*` environment variables

## Repository-specific constraints

- Do not treat `runtime/openpod/vendor/opencode/packages/superpowers` as a normal local refactor target unless the task is explicitly about updating the vendored upstream package
- When updating vendored OpenCode packages, preserve upstream package-root layout; do not flatten only `.opencode/plugins/*.js` or only copy `skills/`
- `runtime/openpod/vendor/opencode/skills/` is intentionally outside the destructive package refresh path in `build/update-vendor-assets.sh`; keep it that way
- Prefer `uv run ...` over bare `python` for one-off scripted shell work in this repo
- If creating GitHub issues for this repo, maintainers prefer GitHub issue forms via the Web UI; `gh issue create` does not automatically apply those forms
