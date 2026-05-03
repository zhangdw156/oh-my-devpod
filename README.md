<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Multi-Flavor_Devpod-2496ED?style=for-the-badge" alt="Multi Flavor Devpod"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>一个 main，多个 AI harness 镜像</strong><br/>
  共享同一套 devpod 基座，同时产出 openpod、claudepod、codexpod、copilotpod、geminipod 五种 flavor。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

---

## 项目概览

当前仓库维护一套共享的 `devpod` 基座：

- Ubuntu 24.04
- Zsh + Powerlevel10k + vendored shell plugins
- Neovim + LazyVim starter
- uv + Python 开发工具
- zellij、btop、yazi、git、rg、fd、atuin、harlequin 等通用开发工具

在这套共同基座上，产出 5 个 flavor：

- `openpod`
- `claudepod`
- `codexpod`
- `copilotpod`
- `geminipod`

这些 flavor 的差异只在：

- 使用的 harness
- 预装的 harness-specific skills
- harness 对应的默认配置与启动入口

## Flavor 说明

### `openpod`

- Harness: OpenCode
- 镜像名：`ghcr.io/zhangdw156/openpod`
- 认证/配置：沿用 OpenCode 模型；用户自行维护项目根 `opencode.json` 或自己的 OpenCode 配置目录

### `claudepod`

- Harness: Claude Code
- 镜像名：`ghcr.io/zhangdw156/claudepod`
- 认证/配置：使用 `claude auth login`、`~/.claude/`、项目内 `.claude/`

### `codexpod`

- Harness: Codex CLI
- 镜像名：`ghcr.io/zhangdw156/codexpod`
- 认证/配置：使用 `codex login`、`~/.codex/`、项目内 Codex 配置

### `copilotpod`

- Harness: GitHub Copilot CLI
- 镜像名：`ghcr.io/zhangdw156/copilotpod`
- 认证/配置：首次运行 `copilot` 后使用 `/login`，或提供 `GH_TOKEN` / `GITHUB_TOKEN`；用户级配置位于 `~/.copilot/`

### `geminipod`

- Harness: Gemini CLI
- 镜像名：`ghcr.io/zhangdw156/geminipod`
- 认证/配置：可使用 Google 登录、`GEMINI_API_KEY`，或 Vertex AI 相关环境变量；用户级配置位于 `~/.gemini/`；headless 场景更建议使用 API key / Vertex AI，而不是浏览器 OAuth

## Docker 用法

### 拉取并使用官方镜像

```bash
docker pull ghcr.io/zhangdw156/claudepod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest
```

其他 flavor：

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest
```

> **注意：** 必须加 `--user "$(id -u):$(id -g)"`，否则容器以 root 运行，会把挂载的项目文件改为 root 所有，导致宿主机上无法正常操作。

直接执行主命令示例：

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

### 通过 compose 运行

```bash
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
docker compose -f docker/copilotpod/docker-compose.yaml run --rm -it copilotpod
docker compose -f docker/geminipod/docker-compose.yaml run --rm -it geminipod
```

compose 默认从 `ghcr.io/zhangdw156/{flavor}:latest` 拉取镜像。镜像版本由仓库根目录 `VERSION` 文件管理；如需指定版本：

```bash
IMAGE_VERSION=0.10.0 docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
```

### 自行构建镜像

如果你需要自定义镜像，可以直接使用 Dockerfile 构建：

```bash
docker build -f Dockerfile.devpod -t devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t codexpod:local .
docker build -f docker/copilotpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t copilotpod:local .
docker build -f docker/geminipod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t geminipod:local .
```

也可以在 compose 文件中取消注释 `build:` 段来通过 compose 构建。

## 一键安装工具链

在任意 Linux 服务器上运行以下命令，即可安装 devpod 全部共享工具链（无需 sudo）：

```bash
# GitHub（默认）
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/setup.sh | bash

# Gitee（国内镜像，GitHub 不可达时使用）
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/setup.sh | bash

# GitLab
curl -fsSL https://gitlab.com/zhangdw156/oh-my-devpod/-/raw/main/install/setup.sh | bash
```

脚本会自动探测 github.com / gitee.com / gitlab.com 的可达性，从可用源下载所有依赖。

宿主机仅需预装 `bash`、`curl` 和 `git`。脚本会自动安装 Homebrew 并通过 brew 管理所有依赖：

- **搜索/导航**: bat, fd, fzf, ripgrep
- **编辑器**: neovim (LazyVim preset)
- **终端**: zellij, yazi, btop, zsh, atuin
- **开发**: gcc, make, node, npm, bun, uv, jq, sqlite, harlequin
- **Shell 插件**: oh-my-zsh, powerlevel10k, autosuggestions, history-substring-search, syntax-highlighting

安装完成后运行 `exec zsh` 即可进入配置好的 zsh 环境。

## 项目结构

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

## 验证

开发改动后优先执行：

```bash
bash tests/run.sh
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help | head -1
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

## 说明

- `devpod` 是共享基座，不是主打给用户直接使用的 flavor
- `openpod`、`claudepod`、`codexpod`、`copilotpod`、`geminipod` 使用同一版本号发布
- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件
