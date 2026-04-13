# Repository Guidelines

## Project Structure & Module Organization
`Dockerfile.devpod` defines the shared base image, each `docker/<flavor>/` directory owns that flavor's `Dockerfile` plus `docker-compose.yaml`, and the repository-root `VERSION` file is the shared source of truth for all six image tags. `runtime/` contains harness-specific launchers, config, installers, skills, and any flavor-owned vendored assets; `runtime/openpod/vendor/opencode/` is the OpenCode-specific asset root. `build/` contains shared installer and asset-refresh scripts. `install/bootstrap.sh` is the shared bootstrap entrypoint with `--flavor`. Shared vendored assets live in `vendor/`, while user docs are in `README.md` and `README_EN.md`; maintainer rules live in `DEVELOPMENT.md` and `docs/vendor-assets.md`.

## Build, Test, and Development Commands
`docker compose -f docker/openpod/docker-compose.yaml build devpod openpod` builds the OpenCode flavor.  
`docker compose -f docker/openpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" openpod -lc 'opencode --version'` smoke-tests the OpenCode flavor.  
`docker compose -f docker/claudepod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" claudepod -lc 'claude --version && claude auth status'` smoke-tests the Claude Code flavor.  
`docker compose -f docker/codexpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" codexpod -lc 'codex --help | sed -n "1,20p"'` smoke-tests the Codex flavor.  
`docker compose -f docker/copilotpod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" copilotpod -lc 'copilot --version'` smoke-tests the Copilot flavor.  
`docker compose -f docker/geminipod/docker-compose.yaml run --rm --user "$(id -u):$(id -g)" geminipod -lc 'gemini --version'` smoke-tests the Gemini flavor.  
`bash install/bootstrap.sh --flavor <flavor> --user` bootstraps one flavor without Docker.  
`bash build/update-vendor-assets.sh` refreshes shared vendored assets and synchronized flavor skills.

## Coding Style & Naming Conventions
This repository is Bash- and YAML-heavy. Use `#!/usr/bin/env bash`, keep `set -euo pipefail`, prefer quoted expansions, `[[ ... ]]`, and lowercase `snake_case` names for variables and functions. Match the existing 2-space indentation in shell blocks and YAML. Keep comments brief and operational. Keep shared logic in `build/` or `Dockerfile.devpod`, and keep harness-specific logic isolated in `runtime/<flavor>/`.

## Testing Guidelines
There is no first-party unit test suite at the root; validation is mostly smoke-based. After behavior changes, run `bash tests/run.sh`, then rebuild and smoke-test affected flavors. When vendored versions change, review `vendor/manifest.lock.json`, `docs/vendor-assets.md`, `runtime/openpod/vendor/opencode/`, and any synchronized flavor skill trees under `runtime/`.

## Development Workflow
Assume the local environment provides the GitHub CLI `gh`; prefer `gh` for repository operations such as inspecting PRs, issues, workflow runs, and preparing PR metadata when those tasks are requested. Use IDD (interface-driven development) by default for substantive changes: clarify or inspect the target interface/contract first, update tests or verification around that contract, then implement and re-verify the behavior.

## Commit & Pull Request Guidelines
Use Conventional Commit messages in `type(scope): summary` format, for example `feat(harness): add copilotpod support` or `chore(version): bump version to 0.9.0.dev1`. Keep subjects imperative and focused; issue refs such as `(#27)` are common. PRs should explain the user-visible effect, list verification commands, link the related issue, and call out any changes to the repository-root `VERSION` file that affect image versions or tags. Include screenshots only when terminal UX, docs examples, or visible config behavior changes.

## Security & Configuration Tips
Never commit API keys or populated harness config. Keep flavor-specific secrets and auth state outside the repository, for example in your OpenCode config, `~/.claude`, or `~/.codex`, depending on the selected harness.
