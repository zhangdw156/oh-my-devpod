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
| **Shell** | Zsh + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) + [Antidote](https://github.com/mattmc3/antidote) | Syntax highlighting, auto-suggestions, Git status |
| **Terminal** | [Zellij](https://github.com/zellij-org/zellij) | Terminal multiplexer for long-lived dev sessions |
| **CLI** | Git / curl / fzf / eza / bat | Modern command-line toolkit |
| **Base** | Ubuntu 24.04 LTS (glibc) | Stable base with full compatibility for Python C extensions |

## Quick Start

### 1. Clone

```bash
git clone --recurse-submodules https://github.com/zhangdw156/oh-my-openpod.git
cd oh-my-openpod
```

<details>
<summary>Forgot <code>--recurse-submodules</code>?</summary>

```bash
git submodule update --init --recursive
```
</details>

### 2. Configure (Optional)

```bash
cp .env.example .env        # Fill in API keys, custom mount path, etc.
cp opencode.json.example opencode.json  # Configure AI provider
```

`.env` supports both official APIs and self-hosted OpenAI / Anthropic compatible endpoints. See [.env.example](.env.example) for details.

### 3. Option A: Build Locally and Start

```bash
# Default: mounts ~/projects
docker compose up -d --build

# Mount a specific project
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

### 4. Option B: Use the Prebuilt GHCR Image

If you do not want to build locally, you can use the image published to GitHub Container Registry directly:

```bash
# Pull the latest stable image
docker pull ghcr.io/zhangdw156/oh-my-openpod:latest

# Or pull a specific version
docker pull ghcr.io/zhangdw156/oh-my-openpod:0.1.0

# Start and enter the container directly
docker run --rm -it \
  --name oh-my-openpod \
  --network host \
  -v "${PROJECT_DIR:-$HOME/projects}:/workspace" \
  -v "$(pwd)/opencode.json:/root/.config/opencode/config.json:ro" \
  --env-file .env \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

This is usually the better choice on servers because it avoids local builds and submodule setup.

Image URL:

```text
ghcr.io/zhangdw156/oh-my-openpod
```

### 5. Enter the Container

If you are using the `docker compose` workflow, enter the container with:

```bash
docker compose exec openpod zsh
```

```
root@hostname /workspace main ❯ opencode   # AI coding assistant
root@hostname /workspace main ❯ zellij     # terminal multiplexer session
root@hostname /workspace main ❯ uv run ... # Python projects
root@hostname /workspace main ❯ git status  # Git operations
```

`zellij` is preinstalled, but it does not auto-start. Run `zellij` manually when you want a multiplexed session.

## Self-Hosted AI Support

Configure `.env` + `opencode.json` to connect to:

- **OpenAI-compatible**: vLLM / Ollama / LiteLLM / SiliconFlow, etc.
- **Anthropic-compatible**: Self-hosted Claude / AWS Bedrock proxy, etc.
- **Official services**: OpenAI / Anthropic APIs

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
| `config/.zsh_plugins.txt` | Antidote plugin list |

```bash
docker compose up -d --build
```

## Project Structure

```
oh-my-openpod/
├── Dockerfile              # Image definition (Ubuntu 24.04)
├── docker-compose.yml      # Orchestration & version
├── build/
│   └── install-zellij.sh   # Install a pinned Zellij release
├── .env.example            # Environment variable template
├── opencode.json.example   # OpenCode AI provider config template
├── config/
│   ├── .zshrc              # Zsh config
│   ├── .p10k.zsh           # Powerlevel10k config
│   └── .zsh_plugins.txt    # Plugin list
└── vendor/
    └── antidote/           # Zsh plugin manager (git submodule)
```

## Contributing

Issues and PRs are welcome! See [DEVELOPMENT.md](DEVELOPMENT.md) for developer documentation.

## License

[MIT](LICENSE)
