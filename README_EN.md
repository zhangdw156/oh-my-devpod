<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Multi-Flavor_Devpod-2496ED?style=for-the-badge" alt="Multi Flavor Devpod"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>One main branch, multiple AI harness images</strong><br/>
  A shared `devpod` base that produces `openpod`, `claudepod`, `codexpod`, `copilotpod`, and `geminipod`.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## One-line Toolchain Install

Run the following command on any Linux server to install the full devpod shared toolchain (no sudo required):

```bash
# GitHub (default)
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/setup.sh | bash

# Gitee (China mirror, use when GitHub is unreachable)
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/setup.sh | bash
```

The script auto-detects reachable git hosts (github.com / gitee.com) and downloads all dependencies from the first available source.

The host only needs `bash`, `curl`, and `git`. The script installs Homebrew and manages all dependencies via brew:

- **Search/Navigation**: bat, fd, fzf, ripgrep
- **Editor**: neovim (LazyVim preset)
- **Terminal**: zellij, yazi, btop, zsh, atuin
- **Development**: gcc, make, node, npm, bun, uv, jq, sqlite, harlequin
- **Shell plugins**: oh-my-zsh, powerlevel10k, autosuggestions, history-substring-search, syntax-highlighting

After installation, run `exec zsh` to enter the configured zsh environment.

## Overview

The repository maintains one shared `devpod` base with common developer tooling:

- Ubuntu 24.04
- Zsh + Powerlevel10k + vendored shell plugins
- Neovim + LazyVim starter
- uv + Python dev tools
- zellij, btop, yazi, git, rg, fd, atuin, harlequin, and other common CLI tooling

On top of that base, the repo builds five runtime flavors:

- `openpod`
- `claudepod`
- `codexpod`
- `copilotpod`
- `geminipod`

The flavors differ only in:

- which harness is installed
- which harness-specific skills are preinstalled
- which harness-specific config and launcher are wired

## Flavor Summary

### `openpod`

- Harness: OpenCode
- Image: `ghcr.io/zhangdw156/openpod`
- Config model: user-managed project `opencode.json` or user-managed OpenCode config directories

### `claudepod`

- Harness: Claude Code
- Image: `ghcr.io/zhangdw156/claudepod`
- Config model: `claude auth login`, `~/.claude/`, project-local `.claude/`

### `codexpod`

- Harness: Codex CLI
- Image: `ghcr.io/zhangdw156/codexpod`
- Config model: `codex login`, `~/.codex/`, project-local Codex config

### `copilotpod`

- Harness: GitHub Copilot CLI
- Image: `ghcr.io/zhangdw156/copilotpod`
- Config model: first-run `/login`, or `GH_TOKEN` / `GITHUB_TOKEN`; user config lives under `~/.copilot/`

### `geminipod`

- Harness: Gemini CLI
- Image: `ghcr.io/zhangdw156/geminipod`
- Config model: Google login, `GEMINI_API_KEY`, or Vertex AI environment variables; user config lives under `~/.gemini/`; headless setups should prefer API key / Vertex AI over browser OAuth

## Docker Usage

### Pull and use official images

```bash
docker pull ghcr.io/zhangdw156/claudepod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest
```

Other flavors:

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest
```

> **Note:** Always include `--user "$(id -u):$(id -g)"` to run the container as your host user. Without it, the container runs as root and changes file ownership under the mounted workspace, making them inaccessible on the host.

Direct command examples:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

### Run with compose

```bash
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
docker compose -f docker/copilotpod/docker-compose.yaml run --rm -it copilotpod
docker compose -f docker/geminipod/docker-compose.yaml run --rm -it geminipod
```

Compose files pull from `ghcr.io/zhangdw156/{flavor}:latest` by default. Image versions are managed by the `VERSION` file at the repository root. To pin a version:

```bash
IMAGE_VERSION=0.10.0 docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
```

### Build images locally

If you need to customize the images, build directly from the Dockerfiles:

```bash
docker build -f Dockerfile.devpod -t devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t codexpod:local .
docker build -f docker/copilotpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t copilotpod:local .
docker build -f docker/geminipod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t geminipod:local .
```

Alternatively, uncomment the `build:` section in the compose files to build via compose.

## Repository Layout

```text
oh-my-devpod/
├── Dockerfile.devpod
├── docker/
│   ├── openpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── claudepod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── codexpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── copilotpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   └── geminipod/
│       ├── Dockerfile
│       └── docker-compose.yaml
├── runtime/
│   ├── openpod/
│   ├── claudepod/
│   ├── codexpod/
│   ├── copilotpod/
│   └── geminipod/
├── build/
├── config/
├── install/
└── vendor/
```

## Verification

After development changes, start with:

```bash
bash tests/run.sh
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help | head -1
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

## Notes

- `devpod` is the shared base, not the primary end-user flavor
- `openpod`, `claudepod`, `codexpod`, `copilotpod`, and `geminipod` should ship under the same version number
- The first `nvim` launch still needs network access because `lazy.nvim` downloads plugins on demand
