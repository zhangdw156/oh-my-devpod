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
- 镜像名：`openpod`
- bootstrap 前缀默认值：`~/.local/openpod`
- 认证/配置：沿用 OpenCode 模型；用户自行维护项目根 `opencode.json` 或自己的 OpenCode 配置目录

### `claudepod`

- Harness: Claude Code
- 镜像名：`claudepod`
- bootstrap 前缀默认值：`~/.local/claudepod`
- 认证/配置：使用 `claude auth login`、`~/.claude/`、项目内 `.claude/`

### `codexpod`

- Harness: Codex CLI
- 镜像名：`codexpod`
- bootstrap 前缀默认值：`~/.local/codexpod`
- 认证/配置：使用 `codex login`、`~/.codex/`、项目内 Codex 配置

### `copilotpod`

- Harness: GitHub Copilot CLI
- 镜像名：`copilotpod`
- bootstrap 前缀默认值：`~/.local/copilotpod`
- 认证/配置：首次运行 `copilot` 后使用 `/login`，或提供 `GH_TOKEN` / `GITHUB_TOKEN`；用户级配置位于 `~/.copilot/`

### `geminipod`

- Harness: Gemini CLI
- 镜像名：`geminipod`
- bootstrap 前缀默认值：`~/.local/geminipod`
- 认证/配置：可使用 Google 登录、`GEMINI_API_KEY`，或 Vertex AI 相关环境变量；用户级配置位于 `~/.gemini/`

## Docker 用法

### 分别构建 5 个 pod 镜像

```bash
docker compose -f docker/openpod/docker-compose.yaml build devpod openpod
docker compose -f docker/claudepod/docker-compose.yaml build devpod claudepod
docker compose -f docker/codexpod/docker-compose.yaml build devpod codexpod
docker compose -f docker/copilotpod/docker-compose.yaml build devpod copilotpod
docker compose -f docker/geminipod/docker-compose.yaml build devpod geminipod
```

构建完成后，镜像会根据 `${IMAGE_VERSION:-local}` 进行打标，例如 `openpod:${IMAGE_VERSION:-local}`。为了让本地 compose 构建的标签与仓库根的 `VERSION` 一致，应使用 `IMAGE_VERSION="$(tr -d '\r' < VERSION)" docker compose ...` 这种前缀写法，或先执行 `export IMAGE_VERSION="$(tr -d '\r' < VERSION)"` 再运行 compose；未设置时默认使用 `local`。

仓库根目录 `VERSION` 是六个镜像共享的版本真源；pod-local compose 文件通过 `${IMAGE_VERSION:-local}` 消费它，默认仅产出 `local` 标签并不在 compose 中保存发布版本号。

### 通过 compose 运行某个 flavor

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
docker compose -f docker/copilotpod/docker-compose.yaml run --rm copilotpod -lc 'copilot --version'
docker compose -f docker/geminipod/docker-compose.yaml run --rm geminipod -lc 'gemini --version'
```

进入交互 shell：

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
docker compose -f docker/copilotpod/docker-compose.yaml run --rm -it copilotpod
docker compose -f docker/geminipod/docker-compose.yaml run --rm -it geminipod
```

### 直接构造镜像

如果你不想走 compose，也可以直接分别构造 pod 镜像：

```bash
docker build -f Dockerfile.devpod -t devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t codexpod:local .
docker build -f docker/copilotpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t copilotpod:local .
docker build -f docker/geminipod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t geminipod:local .
```

### 直接使用镜像

如果镜像已经构建好，也可以不经过 compose，直接运行镜像：

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace openpod:local
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace claudepod:local
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace codexpod:local
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace copilotpod:local
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace geminipod:local
```

> **注意：** 必须加 `--user "$(id -u):$(id -g)"`，否则容器以 root 运行，会把挂载的项目文件改为 root 所有，导致宿主机上无法正常操作。

直接执行主命令示例：

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace openpod:local opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace claudepod:local claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace codexpod:local codex --help
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace copilotpod:local copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace geminipod:local gemini --version
```

## 一键安装工具链

在任意 Linux 服务器上运行以下命令，即可安装 devpod 全部共享工具链（无需 sudo）：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/setup.sh | bash
```

宿主机仅需预装 `bash`、`curl` 和 `git`。脚本会自动安装 Homebrew 并通过 brew 管理所有依赖：

- **搜索/导航**: bat, fd, fzf, ripgrep
- **编辑器**: neovim (LazyVim preset)
- **终端**: zellij, yazi, btop, zsh, atuin
- **开发**: gcc, make, node, npm, bun, uv, jq, sqlite, harlequin
- **Shell 插件**: oh-my-zsh, powerlevel10k, autosuggestions, history-substring-search, syntax-highlighting

安装完成后运行 `exec zsh` 即可进入配置好的 zsh 环境。

## Bootstrap 用法

Bootstrap 仅需宿主机有 `bash`、`curl` 和 `tar`，会自动安装 Homebrew 并通过 brew 管理所有依赖（无需 sudo）。

统一入口：

```bash
bash install/bootstrap.sh --flavor openpod --user
bash install/bootstrap.sh --flavor claudepod --user
bash install/bootstrap.sh --flavor codexpod --user
bash install/bootstrap.sh --flavor copilotpod --user
bash install/bootstrap.sh --flavor geminipod --user
```

安装后常见入口：

```bash
openpod-shell
claudepod-shell
codexpod-shell
copilotpod-shell
geminipod-shell
```

### flavor 认证差异

`openpod`：

- 在项目根使用 `opencode.json`
- 或维护自己的 OpenCode 配置目录

`claudepod`：

- 执行 `claude auth login`
- 或挂载 / 维护 `~/.claude`

`codexpod`：

- 执行 `codex login`
- 或挂载 / 维护 `~/.codex`

`copilotpod`：

- 首次运行 `copilot` 后执行 `/login`
- 或通过 `GH_TOKEN` / `GITHUB_TOKEN` 提供认证
- 可挂载 / 维护 `~/.copilot`

`geminipod`：

- 可使用 Google 登录、`GEMINI_API_KEY` 或 Vertex AI 相关环境变量
- 可挂载 / 维护 `~/.gemini`
- headless 场景更建议使用 API key / Vertex AI，而不是浏览器 OAuth

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
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
docker compose -f docker/copilotpod/docker-compose.yaml run --rm copilotpod -lc 'copilot --version'
docker compose -f docker/geminipod/docker-compose.yaml run --rm geminipod -lc 'gemini --version'
```

## 说明

- `devpod` 是共享基座，不是主打给用户直接使用的 flavor
- `openpod`、`claudepod`、`codexpod`、`copilotpod`、`geminipod` 使用同一版本号发布
- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件
