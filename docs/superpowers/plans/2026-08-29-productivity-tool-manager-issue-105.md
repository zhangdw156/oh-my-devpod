# Productivity Tool Manager Implementation Plan

Issue: #105

## Goal

Deliver a working Ubuntu 24.04 productivity-tool manager with dependency-aware
install/update/uninstall planning, a functional Rust TUI, ownership-safe shell
modules, and GitHub/Gitee release bootstrap support.

## Cleanup sequence

1. Lock the new component, dependency, module, bundle, and bootstrap contracts
   with regression tests.
2. Remove all AI CLI and `uv tool`-managed tool surfaces, then replace the
   hard-coded catalog with `components.toml`.
3. Add catalog validation and deterministic dependency planning.
4. Add bundle-root discovery and module execution.
5. Upgrade the TUI from a selector mock-up to action selection, plan review,
   and execution.
6. Replace legacy modules with productivity-tool modules and ownership markers.
7. Package the complete runtime bundle and add dual-source bootstrap support.
8. Remove obsolete AI CLI and `uv tool` documentation, then align
   repository/Cargo versions.

## Acceptance criteria

- `components.toml` and the repository contain no AI coding CLI or `uv tool`
  managed-tool surfaces.
- `omd --plan install lazyvim` places dependencies before LazyVim.
- unknown components and dependency cycles fail with actionable errors.
- uninstall planning blocks installed reverse dependencies.
- unmanaged components cannot be removed.
- every module supports the complete lifecycle contract and dry-run.
- the TUI supports install, update, and uninstall plan execution.
- release packaging contains all runtime files required after bootstrap.
- GitHub/Gitee source selection and checksum verification are tested.
- `curl | bash` launches `omd` through `/dev/tty`.
- `VERSION` and the Rust crate version agree.
- shell tests, Rust tests, formatting, and diff checks pass.

## Verification

```bash
bash tests/run.sh
cargo fmt --all -- --check
cargo test -p omd
cargo run -p omd -- --list-components
cargo run -p omd -- --plan install lazyvim
git diff --check
```
