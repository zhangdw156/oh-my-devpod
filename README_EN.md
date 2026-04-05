<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Multi-Flavor_Devpod-2496ED?style=for-the-badge" alt="Multi Flavor Devpod"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-openpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-openpod</h1>

<p align="center">
  <strong>One main branch, multiple AI harness images</strong><br/>
  A shared `devpod` base that produces `openpod`, `claudepod`, and `codexpod`.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## Overview

The repository now maintains one shared `devpod` base with common developer tooling:

- Ubuntu 24.04
- Zsh + Powerlevel10k + vendored shell plugins
- Neovim + LazyVim starter
- uv + Python dev tools
- zellij, btop, yazi, git, rg, fd, and other common CLI tooling

On top of that base, the repo builds three runtime flavors:

- `openpod`
- `claudepod`
- `codexpod`

The flavors differ only in:

- which harness is installed
- which harness-specific skills are preinstalled
- which harness-specific config and launcher are wired

## Flavor Summary

### `openpod`

- Harness: OpenCode
- Image: `oh-my-openpod`
- Default bootstrap prefix: `~/.local/openpod`
- Config model: user-managed project `opencode.json` or user-managed OpenCode config directories

### `claudepod`

- Harness: Claude Code
- Image: `oh-my-claudepod`
- Default bootstrap prefix: `~/.local/claudepod`
- Config model: `claude auth login`, `~/.claude/`, project-local `.claude/`

### `codexpod`

- Harness: Codex CLI
- Image: `oh-my-codexpod`
- Default bootstrap prefix: `~/.local/codexpod`
- Config model: `codex login`, `~/.codex/`, project-local Codex config

## Docker Usage

### Build the three pod images separately

```bash
docker compose -f docker/openpod/docker-compose.yaml build devpod openpod
docker compose -f docker/claudepod/docker-compose.yaml build devpod claudepod
docker compose -f docker/codexpod/docker-compose.yaml build devpod codexpod
```

After building, the resulting image names are:

- `oh-my-openpod:0.4.0.dev5`
- `oh-my-claudepod:0.4.0.dev5`
- `oh-my-codexpod:0.4.0.dev5`
- The repository-root `VERSION` file is the shared source of truth for all four image tags; pod-local compose files only consume it

### Run a flavor with compose

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
```

Interactive shell:

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
```

### Build images directly

If you do not want to use compose, you can build the three pod images directly:

```bash
docker build -f Dockerfile.devpod -t oh-my-devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-codexpod:local .
```

### Use the images directly

If the images already exist, you can run them without compose:

```bash
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-openpod:local
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-claudepod:local
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-codexpod:local
```

Direct command examples:

```bash
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-openpod:local opencode --version
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-claudepod:local claude --version
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-codexpod:local codex --help
```

## Bootstrap Usage

Single entrypoint:

```bash
bash install/bootstrap.sh --flavor openpod --user
bash install/bootstrap.sh --flavor claudepod --user
bash install/bootstrap.sh --flavor codexpod --user
```

Common launchers:

```bash
openpod-shell
claudepod-shell
codexpod-shell
```

### Authentication Differences

`openpod`:

- can use a project-level `opencode.json`
- or maintain its own OpenCode config directories
- bootstrap currently expects `node` and `npm` to already exist on the host

`claudepod`:

- use `claude auth login`
- or mount / manage `~/.claude`

`codexpod`:

- use `codex login`
- or mount / manage `~/.codex`
- bootstrap currently expects `node` and `npm` to already exist on the host

## Repository Layout

```text
oh-my-openpod/
├── Dockerfile.devpod
├── docker/
│   ├── openpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── claudepod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   └── codexpod/
│       ├── Dockerfile
│       └── docker-compose.yaml
├── runtime/
│   ├── openpod/
│   ├── claudepod/
│   └── codexpod/
├── build/
├── config/
├── install/
└── vendor/
```

## Verification

After development changes, start with:

```bash
bash tests/run.sh
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
```

## Notes

- `devpod` is the shared base, not the primary end-user flavor
- `openpod`, `claudepod`, and `codexpod` should ship under the same version number
- The first `nvim` launch still needs network access because `lazy.nvim` downloads plugins on demand
