# omd Host Installer Migration Design

Date: 2026-06-09
Status: Approved design draft for user review

## Goal

Convert oh-my-devpod from a Docker image and multi-flavor runtime project into a Linux host installer product. The main user entrypoint becomes a single `curl | bash` bootstrap command that installs and launches a Rust TUI installer named `omd`.

The installer must support first-time setup and repeat runs for installing, updating, adding, and uninstalling software components.

## Non-goals

- Do not keep Docker images, compose files, or flavor images as the primary product surface.
- Do not support macOS or non-Ubuntu distributions in the first version.
- Do not delete user configuration, caches, auth state, tokens, or login sessions during normal uninstall.
- Do not require users to have Rust, Cargo, Node, Bun, Python, `dialog`, or `whiptail` before running the bootstrap command.

## Target Platform

Version 1 supports Ubuntu 24.04 only.

The bootstrap and installer must detect unsupported systems early and exit with a clear message. The default user is expected to have `sudo`; the flow may prompt for the sudo password when installing apt-level prerequisites.

## User Experience

First run:

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

The bootstrap script performs only the minimal work needed to start the real installer:

1. Verify Linux and Ubuntu 24.04.
2. Verify `bash`, `curl`, and a usable shell environment.
3. Verify `sudo` is available and can be used interactively when required.
4. Download the latest compatible prebuilt Linux `omd` binary from GitHub Releases.
5. Install it to `~/.local/bin/omd`.
6. Ensure the user is told how to put `~/.local/bin` on `PATH` when needed.
7. Launch `omd` immediately.

Repeat runs:

```bash
omd
```

The same TUI is used for:

- first-time installation,
- status inspection,
- updating installed components,
- adding optional components,
- uninstalling optional components,
- viewing logs and failure hints.

## TUI Technology

Use Rust with Ratatui and Crossterm.

Rationale:

- Rust can ship a single prebuilt binary for Ubuntu users.
- Ratatui is a mainstream Rust TUI framework and aligns with the terminal-native direction of modern agent CLIs.
- Crossterm provides terminal control without requiring external TUI packages.
- The bootstrap path stays reliable because users do not need Rust installed.

## Installation Layout

User-level paths:

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/
~/.local/state/oh-my-devpod/logs/
~/.cache/oh-my-devpod/
```

Responsibilities:

- `~/.local/bin/omd`: long-lived installer command.
- `~/.local/share/oh-my-devpod/`: installer state, downloaded module snapshots, and component metadata.
- `~/.local/state/oh-my-devpod/logs/`: command logs and failure diagnostics.
- `~/.cache/oh-my-devpod/`: temporary downloads and reusable release artifacts.

The installer should avoid writing to `/usr/local/bin` by default.

## Product Model

The installer manages two component classes.

### Required components

Required components are shown in the TUI but cannot be unchecked or removed through the normal uninstall flow.

Initial required categories:

- Homebrew on Linux.
- zsh environment.
- baseline development tools.

The exact baseline package list is intentionally decided during the implementation planning phase. The current candidate set comes from the existing installer and includes tools such as `neovim`, `uv`, `node`, `ripgrep`, `fzf`, `yazi`, and `zellij`.

### Optional components

Optional components can be installed, updated, added later, or uninstalled.

Initial optional candidates:

- Claude Code.
- Codex.
- OpenCode.
- GitHub Copilot CLI.
- Gemini CLI.

Optional components should preserve user configuration and auth state when uninstalled.

## Component Module Interface

Use a hybrid architecture: Rust owns the TUI, state machine, task orchestration, and logs; shell modules own software-specific installation steps.

Each component module exposes the same command interface:

```bash
module.sh status
module.sh install
module.sh update
module.sh uninstall
```

Expected semantics:

- `status`: report whether the component is installed, missing, required, optional, and whether an update appears available when that can be determined cheaply.
- `install`: install the component idempotently.
- `update`: update or reinstall the component without deleting user data.
- `uninstall`: remove only the software body, wrapper scripts, symlinks, brew packages, npm global packages, or downloaded binary managed by oh-my-devpod.

Normal uninstall must not remove:

- configuration directories,
- caches,
- auth state,
- tokens,
- login sessions.

The first implementation may use exit codes plus line-oriented output. A later hardening pass can move module results to structured JSON if needed.

## Proposed Repository Shape

Target structure:

```text
install/
  bootstrap.sh

crates/
  omd/

modules/
  core/
    brew.sh
    zsh.sh
    base-tools.sh
  optional/
    claude-code.sh
    codex.sh
    opencode.sh
    copilot.sh
    gemini.sh
```

Existing scripts under `build/install-*.sh` should be reused where practical, then gradually reshaped into the module interface. Shell remains the right place for invoking `apt`, `brew`, `npm`, `uv`, and vendor asset operations.

## Docker and Flavor Migration

The migration should happen in two stages.

### Stage 1: Make `omd` the primary path

- Add the Rust TUI installer and bootstrap path.
- Move README focus to the `curl | bash` installer.
- Keep Docker and flavor assets temporarily as legacy implementation and comparison material.
- Keep tests focused on the new bootstrap and module contracts.

### Stage 2: Remove Docker product surfaces

- Remove Dockerfiles, compose files, and flavor runtime wrappers from the supported user-facing product.
- Remove or rewrite Docker-specific tests and release workflows.
- Preserve only migration notes if useful for existing users.

This staged migration avoids deleting the existing product surface before the host installer path is verified.

## Error Handling

The bootstrap script must fail early with clear messages for:

- non-Linux hosts,
- non-Ubuntu 24.04 hosts,
- missing `curl`,
- missing or unusable `sudo`,
- unsupported CPU or missing release binary,
- failed binary download.

The Rust TUI must:

- log each module command,
- show a clear failure state without corrupting the terminal,
- allow retry when the failure is recoverable,
- preserve partial install state for repeat runs,
- direct users to the relevant log file.

## Testing Strategy

Bootstrap tests:

- Ubuntu 24.04 detection accepts valid `/etc/os-release` fixtures.
- Unsupported OS fixtures fail with a clear message.
- Release download URL construction is deterministic.
- Existing `~/.local/bin/omd` handling is safe.

Module contract tests:

- Every module accepts `status`, `install`, `update`, and `uninstall`.
- Unknown actions fail.
- Required modules cannot be uninstalled through the normal TUI path.
- Uninstall commands avoid deleting config, cache, and auth directories.

Rust tests:

- Component state transitions are deterministic.
- Required and optional components render with the right selectable state.
- Failed module commands surface log paths and retry options.

Smoke tests:

- Bootstrap installs or refreshes `omd` into a temporary HOME.
- `omd --version` works after bootstrap.
- A non-interactive dry-run mode can validate planned operations in CI.

## Release Model

GitHub Releases should publish the prebuilt `omd` Linux binary and checksum files. The bootstrap script should download a release artifact rather than compiling from source.

The first release can support one Linux target suitable for Ubuntu 24.04. Additional targets can be added only when there is a tested need.

## Open Decisions for Implementation Planning

These decisions are scoped to the implementation plan rather than this architecture design:

1. The exact required baseline package list.
2. Whether module output should start as line-oriented text or JSON from day one.
3. The exact GitHub Release artifact naming convention.
4. The non-interactive flags needed for CI and server automation.
5. The final README migration wording for users who still use Docker images.
