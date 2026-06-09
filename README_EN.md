<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Rust_TUI_Host_Installer-2496ED?style=for-the-badge" alt="Rust TUI Host Installer"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>One curl entrypoint, one Rust TUI installer</strong><br/>
  Install and manage AI development tooling directly on Ubuntu 24.04 hosts.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## One-line `omd` Start

First run:

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

`install/bootstrap.sh` is a minimal bootstrapper:

1. verifies Ubuntu 24.04,
2. checks `sudo` and may prompt for the sudo password,
3. downloads the prebuilt Rust TUI binary,
4. installs it to `~/.local/bin/omd`,
5. launches `omd`.

Repeat runs use:

```bash
omd
```

## Install Model

`omd` manages two component classes:

- **Required**: Homebrew, zsh environment, and baseline development tools.
- **Optional**: Claude Code, Codex CLI, OpenCode, GitHub Copilot CLI, and Gemini CLI.

Optional uninstall removes only the software body, wrapper, symlink, or oh-my-devpod-managed package prefix. It does not delete user config, caches, auth state, tokens, or login sessions.

Default user-level paths:

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/
~/.local/state/oh-my-devpod/logs/
~/.cache/oh-my-devpod/
```

## Repository Layout

```text
oh-my-devpod/
├── install/
│   ├── bootstrap.sh
│   └── setup.sh
├── crates/
│   └── omd/
├── modules/
│   ├── core/
│   ├── optional/
│   └── lib/
├── build/
├── config/
├── vendor/
├── tests/
├── VERSION
└── versions.env
```

- `install/bootstrap.sh`: public one-line installer entrypoint.
- `crates/omd/`: Rust + Ratatui + Crossterm TUI.
- `modules/`: component lifecycle interface with `status` / `install` / `update` / `uninstall`.
- `build/`: reusable installer scripts and vendored asset refresh scripts.
- `vendor/`: zsh, Neovim, and release asset snapshots.
- `VERSION`: repository-level source of truth for `omd` releases.

## Development Verification

```bash
bash tests/run.sh
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

## Notes

- `omd` is the long-lived command; `curl | bash` only installs and starts it.
- The first version supports Ubuntu 24.04 only.
- Normal uninstall does not delete user config, caches, auth state, or tokens.
- The first `nvim` launch still needs network access because `lazy.nvim` downloads plugins on demand.
