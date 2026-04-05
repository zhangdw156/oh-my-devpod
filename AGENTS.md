# Repository Guidelines

## Project Structure & Module Organization
`Dockerfile.devpod` defines the shared base image, each `docker/<flavor>/` directory owns that flavor's `Dockerfile` plus `docker-compose.yaml`, and the repository-root `VERSION` file is the shared source of truth for all four image tags. `runtime/` contains harness-specific launchers, config, installers, skills, and any flavor-owned vendored assets; `runtime/openpod/vendor/opencode/` is the OpenCode-specific asset root. `build/` contains shared installer and asset-refresh scripts. `install/bootstrap.sh` is the shared bootstrap entrypoint with `--flavor`. Shared vendored assets live in `vendor/`, while user docs are in `README.md` and `README_EN.md`; maintainer rules live in `DEVELOPMENT.md` and `docs/vendor-assets.md`.

## Build, Test, and Development Commands
`docker compose -f docker/openpod/docker-compose.yaml build devpod openpod` builds the OpenCode flavor.  
`docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'` smoke-tests the OpenCode flavor.  
`docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'` smoke-tests the Claude Code flavor.  
`docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'` smoke-tests the Codex flavor.  
`bash install/bootstrap.sh --flavor <flavor> --user` bootstraps one flavor without Docker.  
`bash build/update-vendor-assets.sh` refreshes shared vendored assets and synchronized flavor skills.

## Coding Style & Naming Conventions
This repository is Bash- and YAML-heavy. Use `#!/usr/bin/env bash`, keep `set -euo pipefail`, prefer quoted expansions, `[[ ... ]]`, and lowercase `snake_case` names for variables and functions. Match the existing 2-space indentation in shell blocks and YAML. Keep comments brief and operational. Keep shared logic in `build/` or `Dockerfile.devpod`, and keep harness-specific logic isolated in `runtime/<flavor>/`.

## Testing Guidelines
There is no first-party unit test suite at the root; validation is mostly smoke-based. After behavior changes, run `bash tests/run.sh`, then rebuild and smoke-test affected flavors. When vendored versions change, review `vendor/manifest.lock.json`, `docs/vendor-assets.md`, `runtime/openpod/vendor/opencode/`, and any synchronized flavor skill trees under `runtime/`.

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, and `release:`. Keep subjects imperative and focused; issue refs such as `(#27)` are common. PRs should explain the user-visible effect, list verification commands, link the related issue, and call out any version or tag changes in `docker/<flavor>/docker-compose.yaml`. Include screenshots only when terminal UX, docs examples, or visible config behavior changes.

## Security & Configuration Tips
Never commit API keys or populated harness config. Keep flavor-specific secrets and auth state outside the repository, for example in your OpenCode config, `~/.claude`, or `~/.codex`, depending on the selected harness.
