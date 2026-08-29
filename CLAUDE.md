# CLAUDE.md

This file provides repository guidance for automated coding sessions.

## Repository purpose

`oh-my-devpod` provides a host installer for Ubuntu 24.04. The public entrypoint is `install/bootstrap.sh`, which installs and launches the Rust TUI command `omd`.

`omd` manages selectable Linux development and terminal productivity tools through dependency-aware shell lifecycle modules.

## Core development commands

```bash
bash tests/run.sh
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

Refresh shared vendored assets with:

```bash
bash build/update-vendor-assets.sh
```

## Release and versioning

- The repository-root `VERSION` file is the source of truth for `omd` releases.
- The single source of truth for tool versions such as atuin, btop, neovim, and zellij is `versions.env`.
- Build scripts source `versions.env`; install scripts use matching environment-variable fallbacks. Run `bash tests/test-versions-env.sh` to verify consistency.
- `.github/workflows/release-omd.yml` builds the complete runtime bundle and uploads it plus its checksum to GitHub Releases, with optional Gitee synchronization.
- Release flow details live in `DEVELOPMENT.md`.

## High-level architecture

### 1. Bootstrap entrypoint

`install/bootstrap.sh` is the curl entrypoint. It checks Ubuntu 24.04, selects GitHub or Gitee, verifies the release checksum, installs a versioned runtime bundle, activates `~/.local/bin/omd`, persists the mirror profile, and starts the TUI through `/dev/tty`.

### 2. Rust TUI

`crates/omd/` owns the Rust command. It uses Ratatui and Crossterm for the interactive screen and exposes non-interactive checks:

```bash
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

### 3. Component modules

`modules/` owns shell lifecycle behavior. Every component module accepts:

```bash
module.sh status
module.sh managed
module.sh install
module.sh update
module.sh uninstall
```

Foundation components live under `modules/core/`; selectable tools and managed configuration live under `modules/tools/`. Normal uninstall must not remove external installations or unowned user files.

### 4. Vendored assets

Shared vendored assets live under:

- `vendor/releases/`
- `vendor/zsh/`
- `vendor/nvim/`

`build/update-vendor-assets.sh` refreshes these shared roots. `docs/vendor-assets.md` documents the asset inventory and update workflow.

### 5. Documentation split

- `README.md` / `README_EN.md`: user-facing usage.
- `DEVELOPMENT.md`: maintainer rules, release flow, and asset ownership.
- `docs/vendor-assets.md`: vendored asset sources and refresh workflow.
- `docs/environment-variables.md`: `OHMYDEVPOD_*` environment variable reference.

## GitHub CLI authentication

If a project `.env` token is available, prefer `source .env && GH_TOKEN=$GH_TOKEN gh ...`. If it is not available, verify `gh auth status` before using repository operations.

## Repository-specific constraints

- Keep `install/bootstrap.sh` small and testable; the TUI and lifecycle orchestration belong in `crates/omd/` and `modules/`.
- Keep component-specific package logic in its module file; shared helpers belong in `modules/lib/common.sh`.
- Preserve external installations, user configuration changes, caches, and backups during normal uninstall flows.
- Prefer `uv run ...` over bare `python` for one-off scripted shell work in this repo.
- Use issue-driven development for substantive changes and reference the issue in commits.
