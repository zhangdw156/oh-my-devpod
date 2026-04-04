# Repository Guidelines

## Project Structure & Module Organization
`Dockerfile` and `docker-compose.yml` define the image and local runtime contract. `bin/` holds launcher helpers such as `openpod-shell`; `build/` contains installer and asset-refresh scripts; `install/bootstrap.sh` supports non-Docker bootstrap installs. Shell and OpenCode defaults live in `config/`. User docs are in `README.md` and `README_EN.md`; maintainer rules live in `DEVELOPMENT.md` and `docs/vendor-assets.md`. Vendored, runtime-critical assets are under `vendor/releases/`, `vendor/zsh/`, `vendor/opencode/packages/`, and repo-managed skills under `vendor/opencode/skills/`.

## Build, Test, and Development Commands
`docker compose build` builds the image from the current tree.  
`docker compose up -d --build` rebuilds and starts the default `openpod` container.  
`docker compose exec openpod zsh` opens an interactive shell in the running container.  
`docker compose run --rm openpod -lc 'opencode debug config'` and `docker compose run --rm openpod -lc 'opencode debug skill'` smoke-test OpenCode wiring.  
`bash install/bootstrap.sh --user` bootstraps the same environment without Docker.  
`bash build/update-vendor-assets.sh` refreshes pinned upstream assets before rebuilding.

## Coding Style & Naming Conventions
This repository is Bash- and YAML-heavy. Use `#!/usr/bin/env bash`, keep `set -euo pipefail`, prefer quoted expansions, `[[ ... ]]`, and lowercase `snake_case` names for variables and functions. Match the existing 2-space indentation in shell blocks and YAML. Keep comments brief and operational. Do not reshape vendored package layouts, especially `vendor/opencode/packages/superpowers/`.

## Testing Guidelines
There is no first-party unit test suite at the root; validation is mostly smoke-based. After behavior changes, rebuild the image and run the `opencode debug` checks above. For OpenCode plugin changes, run `bash vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh`. When vendored versions change, review `vendor/manifest.lock.json` and update `docs/vendor-assets.md` if sources or versions changed.

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, and `release:`. Keep subjects imperative and focused; issue refs such as `(#27)` are common. PRs should explain the user-visible effect, list verification commands, link the related issue, and call out any version or tag changes in `docker-compose.yml`. Include screenshots only when terminal UX, docs examples, or visible config behavior changes.

## Security & Configuration Tips
Never commit populated `.env` files or API keys. Keep image-wide defaults in `config/opencode.json`; put project-specific overrides in the mounted workspace `opencode.json`.
