<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-openpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
  <img src="https://img.shields.io/github/license/zhangdw156/oh-my-openpod?style=for-the-badge" alt="License"/>
  <img src="https://img.shields.io/github/stars/zhangdw156/oh-my-openpod?style=for-the-badge&color=yellow" alt="Stars"/>
</p>

<h1 align="center">oh-my-openpod</h1>

<p align="center">
  <strong>AI-Powered Dev Container, Ready in Seconds</strong><br/>
  Spin up OpenCode + uv + Git + Zsh on any machine. Mount your project and start coding.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## Why oh-my-openpod?

> Spent half a day setting up a new machine? No decent shell on the server? Want AI-assisted coding without the setup hassle?

oh-my-openpod packages **AI coding assistant + Python toolchain + beautiful Shell** into one Docker container:

- **2 commands to start** — zero manual dependency installation
- **Mount your project directory** — edit, run, and commit from inside the container
- **Consistent dev experience** — identical across local, server, and CI environments

## What's Inside

| Category | Tool | Description |
|----------|------|-------------|
| **AI** | [OpenCode](https://github.com/opencode-ai/opencode) | Terminal AI coding assistant with custom provider support |
| **Python** | [uv](https://github.com/astral-sh/uv) | Blazingly fast Python package & virtualenv manager |
| **Shell** | Zsh + vendored plugin snapshots + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) + [Antidote](https://github.com/mattmc3/antidote) | Syntax highlighting, auto-suggestions, Git status |
| **Editor** | [Neovim](https://neovim.io/) + [LazyVim Starter](https://github.com/LazyVim/starter) | Default terminal editor setup; first launch bootstraps plugins automatically |
| **Terminal** | [Zellij](https://github.com/zellij-org/zellij) | Terminal multiplexer for long-lived dev sessions |
| **TUI** | [Yazi](https://yazi-rs.github.io/) | Modern terminal file manager for directory browsing and basic file inspection |
| **Monitor** | [btop](https://github.com/aristocratos/btop) | Terminal resource monitor for CPU, memory, and process activity |
| **CLI** | Git / curl / rg / fd / file / vim | Lightweight but practical command-line toolkit |
| **Base** | Ubuntu 24.04 LTS (glibc) | Stable base with full compatibility for Python C extensions |

## Quick Start

### 1. Clone

```bash
git clone https://github.com/zhangdw156/oh-my-openpod.git
cd oh-my-openpod
```

### 2. Configure (Optional)

```bash
cp .env.example .env        # Fill in API keys, custom mount path, etc.
```

The image already bakes in a default global OpenCode config at `/root/.config/opencode/config.json`, including:

- provider definitions that expand values from `.env`
- repository-managed global skills exposed through `/root/.config/opencode/skills -> /opt/vendor/opencode/skills`

If you are using openpod to work on a project and want project-specific OpenCode settings, create `opencode.json` in that project root.

`.env` supports both official APIs and self-hosted OpenAI / Anthropic compatible endpoints. See [.env.example](.env.example) for details.

### 3. Option A: Docker Mode (Recommended)

If you need `.env`, complete [step 2 “Configure (Optional)”](#2-configure-optional) before running the commands below.

```bash
# Default: mounts the current directory (repository root)
docker compose up -d --build

# Mount a different directory
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

Local image builds now use the vendored release assets, Zsh plugin snapshots, and OpenCode plugin packages stored in this repository, so they no longer depend on GitHub release downloads, plugin clones, or runtime plugin fetches during the build.

The remaining network requirement is access to base image registries such as Docker Hub and GHCR.

### 4. Option B: Bootstrap Mode (No Docker / Existing Container)

If the server does not have Docker, or you are already inside an existing Linux container, you can bootstrap the current environment into an openpod-style setup in place.

Initial bootstrap support is intentionally narrow:

- Linux
- Debian/Ubuntu-style environments with `dpkg` and `dpkg-deb`
- user-scoped installs are the preferred default and do not overwrite an existing `~/.zshrc`

```bash
# Default user-scoped install into ~/.local/openpod
bash install/bootstrap.sh --user

# Load openpod environment variables into the current shell
source ~/.local/openpod/env.sh

# Enter the openpod shell
openpod-shell
```

You can also run commands directly without entering an interactive shell first:

```bash
openpod-shell -lc 'opencode debug config'
openpod-shell -lc 'opencode debug skill'
```

If you explicitly want a system-wide install and have root access:

```bash
sudo bash install/bootstrap.sh --system
```

Notes:

- bootstrap mode reuses the vendored release assets, Zsh plugin snapshots, and OpenCode plugin packages stored in this repository
- bootstrap mode installs `neovim` and a managed LazyVim starter config by default; existing unmanaged `nvim` config/data/state/cache paths are backed up automatically on first takeover
- `superpowers` keeps its full upstream package layout intact
- bootstrap mode does not modify your `~/.zshrc`; shell config is written under the install prefix in `shell/`
- `uv` and `opencode` are installed via their official install scripts only if they are missing from the target `bin` directory

### 5. Option C: Use the Prebuilt GHCR Image

If you do not want to build locally, you can use the image published to GitHub Container Registry directly:

```bash
# Pull the latest stable image
docker pull ghcr.io/zhangdw156/oh-my-openpod:latest

# Or pull a specific version
docker pull ghcr.io/zhangdw156/oh-my-openpod:0.1.0
```

**Minimal**: mount the current directory to `/workspace` only (quick try; works without `.env` or a custom `opencode.json`). This path can use the vendored `superpowers` plugin that ships inside the image.

```bash
docker run --rm -it \
  --name openpod \
  --network host \
  -v .:/workspace \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

**Full**: when you need `--env-file .env`, first run `cp .env.example .env` from [step 2](#2-configure-optional), edit it, then run:

If your project root already contains `opencode.json`, mounting that project at `/workspace` lets OpenCode pick up project-level config while the image keeps its baked global defaults at `/root/.config/opencode/config.json`.

```bash
docker run --rm -it \
  --name openpod \
  --network host \
  -v "${PROJECT_DIR:-.}:/workspace" \
  --env-file .env \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

This is usually the better choice on servers because it avoids local builds and any build-time dependency work beyond pulling the base images.

Image URL:

```text
ghcr.io/zhangdw156/oh-my-openpod
```

The default runtime container name is the shorter `openpod`; the project name and image name remain `oh-my-openpod`.

### 6. Enter the Container or Shell

If you are using the `docker compose` workflow, enter the container with:

```bash
docker compose exec openpod zsh
```

```
root@hostname /workspace main ❯ opencode   # AI coding assistant
root@hostname /workspace main ❯ nvim       # Neovim with the default LazyVim starter
root@hostname /workspace main ❯ zellij     # terminal multiplexer session
root@hostname /workspace main ❯ y          # Yazi file manager with cwd sync
root@hostname /workspace main ❯ btop       # resource monitor
root@hostname /workspace main ❯ uv run ... # Python projects
root@hostname /workspace main ❯ git status  # Git operations
```

`zellij` is preinstalled, but it does not auto-start. Run `zellij` manually when you want a multiplexed session.
`y` is a shell wrapper around `yazi`; when you quit Yazi, it syncs the selected working directory back to the shell.
The first `nvim` launch still needs network access because `lazy.nvim` downloads the plugin set on demand.

## Self-Hosted AI Support

Configure `.env` to connect to:

- **OpenAI-compatible**: vLLM / Ollama / LiteLLM / SiliconFlow, etc.
- **Anthropic-compatible**: Self-hosted Claude / AWS Bedrock proxy, etc.
- **Official services**: OpenAI / Anthropic APIs

The image bakes in the default global OpenCode config at `/root/.config/opencode/config.json`, preinstalls the vendored `superpowers` OpenCode plugin, and exposes repository-managed global skills through `/root/.config/opencode/skills -> /opt/vendor/opencode/skills`.

If you place `opencode.json` in the project root mounted at `/workspace`, OpenCode can also pick up project-level configuration for that project.

You do not need to add the bundled `superpowers` skills to `skills.paths` manually because the plugin registers its own `skills/` directory at runtime.

```bash
# .env example
CUSTOM_OPENAI_BASE_URL=https://your-host/v1
CUSTOM_OPENAI_API_KEY=your-api-key
CUSTOM_OPENAI_MODEL=your-model-name
```

## Customize Zsh

Config files are in the `config/` directory. Rebuild after editing:

| File | Description |
|------|-------------|
| `config/.zshrc` | Zsh main config |
| `config/.p10k.zsh` | Powerlevel10k theme |
| `config/.zsh_plugins.txt` | Vendored plugin inventory |

```bash
docker compose up -d --build
```

## Project Structure

```
oh-my-openpod/
├── Dockerfile              # Image definition (Ubuntu 24.04)
├── docker-compose.yml      # Orchestration & version
├── build/
│   ├── install-antidote.sh # Install Antidote
│   ├── install-btop.sh     # Install btop
│   ├── install-lazyvim.sh  # Install the default LazyVim starter config
│   ├── install-neovim.sh   # Install Neovim
│   ├── update-vendor-assets.sh # Refresh vendored release assets, plugin snapshots, and OpenCode plugin packages
│   ├── install-yazi.sh     # Install Yazi
│   └── install-zellij.sh   # Install Zellij
├── docs/
│   └── vendor-assets.md    # Vendored asset sources and maintenance notes
├── .env.example            # Environment variable template
├── config/
│   ├── .zshrc              # Zsh config
│   ├── .p10k.zsh           # Powerlevel10k config
│   ├── .zsh_plugins.txt    # Vendored plugin inventory
│   └── opencode.json       # Baked-in global OpenCode default config
├── tests/
│   └── run.sh              # Shell regression test entrypoint for installers and wiring
└── vendor/
    ├── manifest.lock.json  # Vendored asset lock file
    ├── nvim/
    │   └── lazyvim-starter/ # Pinned LazyVim starter snapshot
    ├── opencode/
    │   ├── packages/       # OpenCode plugin packages that keep upstream layout
    │   └── skills/         # Repository-managed OpenCode global skills
    ├── releases/           # Pinned release packages used by build scripts
    └── zsh/                # Zsh plugin source snapshots
```

## Contributing

Issues and PRs are welcome! See [DEVELOPMENT.md](DEVELOPMENT.md) for developer documentation and [docs/vendor-assets.md](docs/vendor-assets.md) for vendored asset details.

## License

[MIT](LICENSE)
