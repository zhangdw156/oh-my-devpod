# Repository Guidelines

## Project Structure & Module Organization
`install/bootstrap.sh` is the public GitHub/Gitee installer entrypoint, `components.toml` is the component and dependency catalog, `crates/omd/` owns the Rust + Ratatui TUI and planner, and `modules/` owns lifecycle scripts with `status`, `managed`, `install`, `update`, and `uninstall` actions. `build/` contains reusable installers, release packaging, and asset-refresh scripts. `config/` and `vendor/` contain shell/editor configuration and pinned release assets. The repository-root `VERSION` file is the source of truth for `omd` releases.

## Build, Test, and Development Commands
`bash tests/run.sh` runs the shell regression suite plus `cargo test -p omd` when Cargo is available. Use `cargo test -p omd` for Rust unit tests, `cargo run -p omd -- --version` for a CLI smoke check, `cargo run -p omd -- --plan install lazyvim` for dependency planning, and `cargo run -p omd -- --list-components` to inspect the catalog. `bash build/package-omd.sh` creates a release bundle, and `bash build/update-vendor-assets.sh` refreshes vendored assets.

## Coding Style & Naming Conventions
This repository is Bash-, Rust-, and YAML-heavy. Use `#!/usr/bin/env bash`, keep `set -euo pipefail`, prefer quoted expansions, `[[ ... ]]`, and lowercase `snake_case` names for shell variables and functions. Run `cargo fmt --all` for Rust changes. Match the existing 2-space indentation in shell blocks and YAML. Keep comments brief and operational. Keep shared install logic in `build/` or `modules/lib/`, TUI logic in `crates/omd/`, and component-specific lifecycle behavior in `modules/core/` or `modules/tools/`.

## Testing Guidelines
After behavior changes, run `bash tests/run.sh`, `cargo test -p omd`, and `git diff --check`. For bootstrap changes, run `bash tests/test-bootstrap.sh`; for module changes, run `bash tests/test-module-contracts.sh`; for release workflow changes, run `bash tests/test-omd-release-workflow.sh`. When vendored versions change, review `vendor/manifest.lock.json`, `docs/vendor-assets.md`, and the relevant `build/install-*.sh` fallback defaults.

## Development Workflow
Assume the local environment provides the GitHub CLI `gh`; prefer `gh` for repository operations such as inspecting PRs, issues, workflow runs, and preparing PR metadata when those tasks are requested. Use issue-driven development for substantive changes: create or reference an issue, clarify the target interface/contract, update tests around that contract, then implement and re-verify behavior.

## Commit & Pull Request Guidelines
Use Conventional Commit messages in `type(scope): summary` format, for example `feat(installer): add component action` or `chore(version): bump version to 0.9.0.dev1`. Keep subjects imperative and focused; issue refs such as `Refs #103` are expected for implementation commits. PRs should explain the user-visible effect, list verification commands, link the related issue, and call out any changes to `VERSION` that affect `omd` release artifacts.

## Security & Configuration Tips
Never commit API keys, credentials, or token files. Normal uninstall paths must remove only artifacts carrying a matching oh-my-devpod ownership marker. Preserve external installations, user configuration changes, caches, and backups.
