<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Claude_Code-Ready-D97757?style=for-the-badge" alt="Claude Code"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-openpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
  <img src="https://img.shields.io/github/license/zhangdw156/oh-my-openpod?style=for-the-badge" alt="License"/>
</p>

<h1 align="center">oh-my-claudepod</h1>

<p align="center">
  <strong>Claude Code 开发容器，开箱即用</strong><br/>
  在任意机器上一键拉起 Claude Code + uv + Git + Zsh 环境，挂载你的项目目录即可开始工作。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

---

## 这是什么

`dev/claude` 分支把原本的 OpenCode 运行时替换成了 Claude Code，同时尽量保留原有 openpod 的使用体验：

- Docker 模式和 bootstrap 模式都可用
- 继续复用 vendored 的 Zsh、Neovim、Yazi、Zellij、btop 等资产
- 认证和 Claude 配置完全交给用户自己管理

这条分支的公开镜像名是 `oh-my-claudepod`，默认服务名和容器名是 `claudepod`。

## 内置工具

| 类别 | 工具 | 说明 |
|------|------|------|
| **AI** | [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | 终端 AI 编程助手 |
| **Python** | [uv](https://github.com/astral-sh/uv) | Python 包管理器与虚拟环境工具 |
| **Shell** | Zsh + vendored 插件快照 + Powerlevel10k + Antidote | 语法高亮、补全、Git 状态提示 |
| **Editor** | Neovim + LazyVim Starter | 默认终端编辑器配置，预装 `pyright[nodejs]` 与 `ruff` |
| **Terminal** | Zellij | 终端多路复用器 |
| **TUI** | Yazi | 终端文件管理器 |
| **Monitor** | btop | 资源监控 |
| **CLI** | Git / curl / rg / fd / file / vim | 轻量但够用的命令行工具集 |

## 快速开始

### 1. 克隆仓库并切到分支

```bash
git clone https://github.com/zhangdw156/oh-my-openpod.git
cd oh-my-openpod
git switch dev/claude
```

### 2. 准备 Claude 配置

这条分支不再消费 `.env`，也不会替你生成 Claude 的认证配置。

可用的原生方式只有三种：

- 在容器或 bootstrap 环境里执行 `claude auth login`
- 挂载或复用你自己维护的 `~/.claude`
- 在项目里自己写 `.claude/settings.json`、`.claude/settings.local.json` 和 `CLAUDE.md`

### 3. Docker 模式

```bash
docker compose up -d --build
```

挂载其它目录：

```bash
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

进入容器：

```bash
docker compose exec claudepod zsh
```

常用 smoke check：

```bash
docker compose run --rm claudepod -lc 'claude --version'
docker compose run --rm claudepod -lc 'claude doctor'
```

如果你已经先完成 `claude auth login` 或提供了自己的 Claude 配置，再做最小非交互调用：

```bash
docker compose run --rm claudepod -lc 'claude -p "Reply with OK"'
```

### 4. Bootstrap 模式

适用于无 Docker 的 Linux 主机，或者你已经在现成容器里。

```bash
# 默认用户态安装到 ~/.local/claudepod
bash install/bootstrap.sh --user

# 加载环境变量
source ~/.local/claudepod/env.sh

# 进入 shell
claudepod-shell
```

系统级安装：

```bash
sudo bash install/bootstrap.sh --system
```

bootstrap 完成后可以验证：

```bash
claudepod-shell -lc 'claude --version'
claudepod-shell -lc 'claude doctor'
```

为了兼容旧习惯，`openpod-shell` 仍然保留，但文档中的主入口已经切换为 `claudepod-shell`。

### 5. 直接使用 GHCR 镜像

```bash
docker pull ghcr.io/zhangdw156/oh-my-claudepod:latest
```

最简运行：

```bash
docker run --rm -it \
  --name claudepod \
  --network host \
  -v .:/workspace \
  ghcr.io/zhangdw156/oh-my-claudepod:latest
```

如果你想复用宿主机上的 Claude 登录态或设置，可以直接挂载 `~/.claude`：

```bash
docker run --rm -it \
  --name claudepod \
  --network host \
  -v "${PROJECT_DIR:-.}:/workspace" \
  -v ~/.claude:/root/.claude \
  ghcr.io/zhangdw156/oh-my-claudepod:latest
```

## 配置模型

### 全局配置

Claude 的用户级配置位于：

```text
~/.claude/settings.json
```

这条分支不会再额外生成受管认证状态文件。Claude 的认证和设置都由你自己控制。

### 项目级配置

项目级配置入口改成：

- `.claude/settings.json`
- `.claude/settings.local.json`
- `CLAUDE.md`

## 迁移说明

`dev/claude` 不再使用下面这些 OpenCode 时代的概念：

- `opencode.json`
- `~/.config/opencode`
- OpenCode plugin 目录
- `vendor/opencode/...`

如果你的项目之前依赖 `opencode.json`，请迁移到 `.claude/settings.json` 和 `CLAUDE.md`。

## 仓库结构

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

## 验证

开发改动后，优先跑：

```bash
bash tests/run.sh
docker compose build
docker compose run --rm claudepod -lc 'claude --version'
docker compose run --rm claudepod -lc 'claude doctor'
```

## 说明

- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件
- 本地构建仍然需要访问基础镜像仓库，比如 Docker Hub 和 GHCR
- 这条分支聚焦 Claude Code 官方支持的接入面，不处理 OpenAI-compatible provider 兼容层
