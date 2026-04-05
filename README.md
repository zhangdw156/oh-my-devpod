<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Multi-Flavor_Devpod-2496ED?style=for-the-badge" alt="Multi Flavor Devpod"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-openpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-openpod</h1>

<p align="center">
  <strong>一个 main，多个 AI harness 镜像</strong><br/>
  共享同一套 devpod 基座，同时产出 openpod、claudepod、codexpod 三种 flavor。
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
- zellij、btop、yazi、git、rg、fd 等通用开发工具

在这套共同基座上，产出 3 个 flavor：

- `openpod`
- `claudepod`
- `codexpod`

三者的差异只在：

- 使用的 harness
- 预装的 harness-specific skills
- harness 对应的默认配置与启动入口

## Flavor 说明

### `openpod`

- Harness: OpenCode
- 镜像名：`oh-my-openpod`
- bootstrap 前缀默认值：`~/.local/openpod`
- 认证/配置：沿用 OpenCode 模型；用户自行维护项目根 `opencode.json` 或自己的 OpenCode 配置目录

### `claudepod`

- Harness: Claude Code
- 镜像名：`oh-my-claudepod`
- bootstrap 前缀默认值：`~/.local/claudepod`
- 认证/配置：使用 `claude auth login`、`~/.claude/`、项目内 `.claude/`

### `codexpod`

- Harness: Codex CLI
- 镜像名：`oh-my-codexpod`
- bootstrap 前缀默认值：`~/.local/codexpod`
- 认证/配置：使用 `codex login`、`~/.codex/`、项目内 Codex 配置

## Docker 用法

### 分别构建 3 个 pod 镜像

```bash
docker compose -f docker/openpod/docker-compose.yaml build devpod openpod
docker compose -f docker/claudepod/docker-compose.yaml build devpod claudepod
docker compose -f docker/codexpod/docker-compose.yaml build devpod codexpod
```

构建完成后，对应镜像名分别是：

- `oh-my-openpod:0.4.0.dev5`
- `oh-my-claudepod:0.4.0.dev5`
- `oh-my-codexpod:0.4.0.dev5`

### 通过 compose 运行某个 flavor

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
```

进入交互 shell：

```bash
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
```

### 直接构造镜像

如果你不想走 compose，也可以直接分别构造 3 个 pod 镜像：

```bash
docker build -f Dockerfile.devpod -t oh-my-devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=oh-my-devpod:local -t oh-my-codexpod:local .
```

### 直接使用镜像

如果镜像已经构建好，也可以不经过 compose，直接运行镜像：

```bash
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-openpod:local
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-claudepod:local
docker run --rm -it --network host -v "$PWD:/workspace" -w /workspace oh-my-codexpod:local
```

直接执行主命令示例：

```bash
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-openpod:local opencode --version
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-claudepod:local claude --version
docker run --rm --network host -v "$PWD:/workspace" -w /workspace oh-my-codexpod:local codex --help
```

## Bootstrap 用法

统一入口：

```bash
bash install/bootstrap.sh --flavor openpod --user
bash install/bootstrap.sh --flavor claudepod --user
bash install/bootstrap.sh --flavor codexpod --user
```

安装后常见入口：

```bash
openpod-shell
claudepod-shell
codexpod-shell
```

### flavor 认证差异

`openpod`：

- 在项目根使用 `opencode.json`
- 或维护自己的 OpenCode 配置目录
- 当前 bootstrap 需要宿主机已安装 `node` 和 `npm`

`claudepod`：

- 执行 `claude auth login`
- 或挂载 / 维护 `~/.claude`

`codexpod`：

- 执行 `codex login`
- 或挂载 / 维护 `~/.codex`
- 当前 bootstrap 需要宿主机已安装 `node` 和 `npm`

## 项目结构

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

## 验证

开发改动后优先执行：

```bash
bash tests/run.sh
docker compose -f docker/openpod/docker-compose.yaml run --rm openpod -lc 'opencode --version'
docker compose -f docker/claudepod/docker-compose.yaml run --rm claudepod -lc 'claude --version && claude auth status'
docker compose -f docker/codexpod/docker-compose.yaml run --rm codexpod -lc 'codex --help | sed -n "1,20p"'
```

## 说明

- `devpod` 是共享基座，不是主打给用户直接使用的 flavor
- `openpod`、`claudepod`、`codexpod` 使用同一版本号发布
- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件
