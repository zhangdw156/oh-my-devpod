<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Claude_Code-Ready-D97757?style=for-the-badge" alt="Claude Code"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-openpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
  <img src="https://img.shields.io/github/license/zhangdw156/oh-my-openpod?style=for-the-badge" alt="License"/>
</p>

<h1 align="center">oh-my-claudepod</h1>

<p align="center">
  <strong>Claude Code Dev Container, Ready in Seconds</strong><br/>
  Spin up Claude Code + uv + Git + Zsh on any machine. Mount your project and start coding.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## What This Branch Does

The `dev/claude` branch replaces the old OpenCode runtime with Claude Code while keeping the surrounding openpod workflow intact:

- Docker mode and bootstrap mode are both supported
- vendored shell/editor/runtime assets stay in place
- authentication and Claude config are fully user-managed

The public image name on this branch is `oh-my-claudepod`, and the default service/container name is `claudepod`.

## What's Inside

| Category | Tool | Description |
|----------|------|-------------|
| **AI** | [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | Terminal AI coding assistant |
| **Python** | [uv](https://github.com/astral-sh/uv) | Python package manager and virtualenv tool |
| **Shell** | Zsh + vendored plugin snapshots + Powerlevel10k + Antidote | Syntax highlighting, completion, Git status |
| **Editor** | Neovim + LazyVim Starter | Default terminal editor setup with preinstalled `pyright[nodejs]` and `ruff` |
| **Terminal** | Zellij | Terminal multiplexer |
| **TUI** | Yazi | Terminal file manager |
| **Monitor** | btop | Resource monitor |
| **CLI** | Git / curl / rg / fd / file / vim | Lightweight but practical command-line toolkit |

## Quick Start

### 1. Clone The Repo And Switch Branches

```bash
git clone https://github.com/zhangdw156/oh-my-openpod.git
cd oh-my-openpod
git switch dev/claude
```

### 2. Prepare Claude Configuration

This branch no longer consumes `.env` and no longer generates Claude auth settings for you.

Use one of the native Claude paths instead:

- run `claude auth login` inside the container or bootstrap environment
- mount or reuse your own `~/.claude`
- maintain project-local `.claude/settings.json`, `.claude/settings.local.json`, and `CLAUDE.md`

### 3. Docker Mode

```bash
docker compose up -d --build
```

Mount a different workspace:

```bash
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

Enter the container:

```bash
docker compose exec claudepod zsh
```

Basic smoke checks:

```bash
docker compose run --rm claudepod -lc 'claude --version'
docker compose run --rm claudepod -lc 'claude doctor'
```

If you already completed `claude auth login` or supplied your own Claude config, you can also run a minimal non-interactive prompt:

```bash
docker compose run --rm claudepod -lc 'claude -p "Reply with OK"'
```

### 4. Bootstrap Mode

Use this on a Linux host without Docker, or inside an existing container:

```bash
# Default user-scoped install into ~/.local/claudepod
bash install/bootstrap.sh --user

# Load environment variables
source ~/.local/claudepod/env.sh

# Enter the shell
claudepod-shell
```

System-wide install:

```bash
sudo bash install/bootstrap.sh --system
```

Bootstrap verification:

```bash
claudepod-shell -lc 'claude --version'
claudepod-shell -lc 'claude doctor'
```

`openpod-shell` is still shipped as a compatibility alias, but `claudepod-shell` is the primary entrypoint on this branch.

### 5. Use The Prebuilt GHCR Image

```bash
docker pull ghcr.io/zhangdw156/oh-my-claudepod:latest
```

Minimal run:

```bash
docker run --rm -it \
  --name claudepod \
  --network host \
  -v .:/workspace \
  ghcr.io/zhangdw156/oh-my-claudepod:latest
```

If you want to reuse Claude login state or settings from the host, mount `~/.claude`:

```bash
docker run --rm -it \
  --name claudepod \
  --network host \
  -v "${PROJECT_DIR:-.}:/workspace" \
  -v ~/.claude:/root/.claude \
  ghcr.io/zhangdw156/oh-my-claudepod:latest
```

## Configuration Model

### Global Settings

Claude user settings live at:

```text
~/.claude/settings.json
```

This branch no longer maintains a managed auth state file. Claude authentication and settings remain entirely under user control.

### Project Settings

Project-level configuration now lives in:

- `.claude/settings.json`
- `.claude/settings.local.json`
- `CLAUDE.md`

## Migration Notes

`dev/claude` no longer uses these OpenCode-era concepts:

- `opencode.json`
- `~/.config/opencode`
- OpenCode plugin directories
- `vendor/opencode/...`

If your project previously relied on `opencode.json`, move that configuration to `.claude/settings.json` and `CLAUDE.md`.

## Repository Layout

```text
oh-my-openpod/
├── Dockerfile
├── docker-compose.yml
├── build/
│   ├── install-claude-code.sh
│   ├── install-antidote.sh
│   ├── install-btop.sh
│   ├── install-lazyvim.sh
│   ├── install-neovim.sh
│   ├── install-python-dev-tools.sh
│   ├── install-yazi.sh
│   ├── install-zellij.sh
│   └── update-vendor-assets.sh
├── bin/
│   ├── claude
│   ├── claudepod-shell
│   └── openpod-shell
├── config/
│   ├── nvim/
│   ├── .zshrc
│   └── .p10k.zsh
├── install/
│   └── bootstrap.sh
└── vendor/
    ├── claude/
    │   └── skills/
    ├── nvim/
    ├── releases/
    └── zsh/
```

## Verification

After development changes, start with:

```bash
bash tests/run.sh
docker compose build
docker compose run --rm claudepod -lc 'claude --version'
docker compose run --rm claudepod -lc 'claude doctor'
```

## Notes

- The first `nvim` launch still needs network access because `lazy.nvim` downloads plugins on demand
- Local builds still need access to base image registries such as Docker Hub and GHCR
- This branch intentionally focuses on Claude Code official integration surfaces and does not provide an OpenAI-compatible provider shim
