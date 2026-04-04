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
  <strong>AI 编程开发容器，开箱即用</strong><br/>
  在任意机器上一键拉起 OpenCode + uv + Git + Zsh 环境，挂载你的项目目录即可开始工作。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

---

## 为什么需要 oh-my-openpod？

> 换了一台机器，花了半天配环境？服务器上没有趁手的 Shell？想用 AI 辅助编程却懒得装？

oh-my-openpod 把 **AI 编程助手 + Python 工具链 + 美观 Shell** 打包成一个 Docker 容器：

- **2 条命令启动**，无需手动安装任何依赖
- **挂载你的项目目录**，在容器内直接编辑、运行、提交
- **一致的开发体验**，本地、服务器、CI 环境完全相同

## 内置工具一览

| 类别 | 工具 | 说明 |
|------|------|------|
| **AI** | [OpenCode](https://github.com/opencode-ai/opencode) | 终端 AI 编程助手，支持自定义 Provider |
| **Python** | [uv](https://github.com/astral-sh/uv) | 极速 Python 包管理器 & 虚拟环境管理 |
| **Shell** | Zsh + vendored 插件快照 + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) + [Antidote](https://github.com/mattmc3/antidote) | 语法高亮、自动补全、Git 状态提示 |
| **Editor** | [Neovim](https://neovim.io/) + [LazyVim Starter](https://github.com/LazyVim/starter) | 默认内置的终端编辑器配置，预装 `pyright[nodejs]` 与 `ruff`，首次启动自动引导插件安装 |
| **Terminal** | [Zellij](https://github.com/zellij-org/zellij) | 终端多路复用器，适合长时间开发会话 |
| **TUI** | [Yazi](https://yazi-rs.github.io/) | 现代化终端文件管理器，适合目录浏览和基础文件查看 |
| **Monitor** | [btop](https://github.com/aristocratos/btop) | 终端资源监控面板，便于查看容器内 CPU、内存和进程状态 |
| **CLI** | Git / curl / rg / fd / file / vim | 轻量但够用的命令行工具集 |
| **系统** | Ubuntu 24.04 LTS (glibc) | 稳定底座，兼容主流 Python C 扩展 |

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/zhangdw156/oh-my-openpod.git
cd oh-my-openpod
```

### 2. 配置（可选）

```bash
cp .env.example .env        # 填入 API Key、自定义挂载路径等
```

镜像默认已经内置 OpenCode 全局配置文件 `/root/.config/opencode/config.json`，其中包含：

- 基于 `.env` 变量展开的 provider 定义
- 通过 `/root/.config/opencode/skills -> /opt/vendor/opencode/skills` 暴露的仓库维护全局 skills

如果你在用 openpod 开发某个项目，并且希望给该项目单独配置 OpenCode，请直接在项目根目录创建 `opencode.json`。

`.env` 支持官方 API 和自部署的 OpenAI / Anthropic 兼容接口，详见 [.env.example](.env.example)。

### 3. 方式 A：Docker 模式（默认推荐）

若需使用 `.env`，请先完成 [第 2 步「配置（可选）」](#2-配置可选) 再执行下方命令。

```bash
# 默认挂载当前目录（仓库根目录）
docker compose up -d --build

# 挂载其它目录
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

本地构建默认直接使用仓库内 vendored 的 release 包、Zsh 插件快照和 OpenCode 插件包，因此不再依赖 GitHub release、插件仓库或 OpenCode 插件仓库的运行时拉取。

仍然需要联网的只有基础镜像来源，例如 Docker Hub 和 GHCR。

### 4. 方式 B：Bootstrap 模式（无 Docker / 已有容器）

当服务器上没有 Docker，或者你已经在一个现成的 Linux 容器里时，可以直接把当前环境 bootstrap 成 openpod 风格环境。

当前 bootstrap 模式的初始支持范围：

- Linux
- Debian / Ubuntu 风格环境（要求 `dpkg` / `dpkg-deb` 可用）
- 推荐优先使用用户态安装，不覆盖现有 `~/.zshrc`

```bash
# 默认用户态安装到 ~/.local/openpod
bash install/bootstrap.sh --user

# 让当前 shell 获取 openpod 环境变量
source ~/.local/openpod/env.sh

# 进入 openpod shell
openpod-shell
```

也可以直接执行命令而不先进入交互 shell：

```bash
openpod-shell -lc 'opencode debug config'
openpod-shell -lc 'opencode debug skill'
```

如需系统级安装，可在具备 root 权限时使用：

```bash
sudo bash install/bootstrap.sh --system
```

注意：

- bootstrap 模式会复用仓库内 vendored 的 release 包、Zsh 插件快照和 OpenCode 插件包
- 默认会安装 `neovim` 和一份受 openpod 管理的 LazyVim starter 配置；首次接管已有 `nvim` 目录时会自动备份
- 默认会通过 `uv tool install` 预装 `pyright[nodejs]` 与 `ruff`，便于在 `nvim` 中直接获得 Python 诊断与补全
- `superpowers` 仍然保持完整包结构，不会被拆平
- 当前不会自动修改你的 `~/.zshrc`；shell 配置会写到安装前缀下的 `shell/` 目录
- `uv` 和 `opencode` 在目标 `bin` 目录不存在时会通过各自官方安装脚本补齐

### 5. 方式 C：直接使用 GHCR 预构建镜像

如果你不想在本地构建，也可以直接使用发布到 GitHub Container Registry 的镜像：

```bash
# 拉取最新正式版
docker pull ghcr.io/zhangdw156/oh-my-openpod:latest

# 或拉取指定版本
docker pull ghcr.io/zhangdw156/oh-my-openpod:0.1.0
```

**最简**：只把当前目录挂到 `/workspace`（适合快速试用；无 `.env` / 自定义 `opencode.json` 时也可用）。此方式可直接使用镜像内预置的 vendored `superpowers` 插件。

```bash
docker run --rm -it \
  --name openpod \
  --network host \
  -v .:/workspace \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

**完整**：需要 `--env-file .env` 时，请先按 [第 2 步](#2-配置可选) 执行 `cp .env.example .env` 并编辑好，再运行：

如果你的项目根目录本身带有 `opencode.json`，把该项目挂到 `/workspace` 后即可让 OpenCode 使用项目级配置；镜像内置的全局默认配置仍然保留在 `/root/.config/opencode/config.json`。

```bash
docker run --rm -it \
  --name openpod \
  --network host \
  -v "${PROJECT_DIR:-.}:/workspace" \
  --env-file .env \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

对于服务器环境，更推荐这种方式：无需本地 build，也不用关心基础镜像拉取之外的构建依赖。

镜像地址：

```text
ghcr.io/zhangdw156/oh-my-openpod
```

默认运行容器名使用更短的 `openpod`；项目名和镜像名仍然保持为 `oh-my-openpod`。

### 6. 进入容器或 shell，开始工作

如果你使用的是 `docker compose` 方式，可以这样进入容器：

```bash
docker compose exec openpod zsh
```

```
root@hostname /workspace main ❯ opencode   # AI 编程助手
root@hostname /workspace main ❯ nvim       # 默认内置的 Neovim + LazyVim starter
root@hostname /workspace main ❯ pyright    # Python LSP / 类型检查
root@hostname /workspace main ❯ ruff check . # Python lint / format 相关工具
root@hostname /workspace main ❯ zellij     # 终端多路复用会话
root@hostname /workspace main ❯ y          # Yazi 文件管理器（退出时同步 cwd）
root@hostname /workspace main ❯ btop       # 资源监控面板
root@hostname /workspace main ❯ uv run ... # Python 项目
root@hostname /workspace main ❯ git status  # Git 操作
```

`zellij` 已预装，但默认不会自动接管 shell；按需手动执行 `zellij` 即可进入会话。
`y` 是 `yazi` 的 shell wrapper；退出 Yazi 后会把当前目录同步回 shell。
首次执行 `nvim` 时仍然需要联网，因为 `lazy.nvim` 会按需拉取插件集。

## 支持自部署 AI 服务

通过 `.env` 配置，可以对接：

- **OpenAI 兼容接口**：vLLM / Ollama / LiteLLM / 硅基流动 等
- **Anthropic 兼容接口**：自部署 Claude / AWS Bedrock 代理 等
- **官方服务**：OpenAI / Anthropic 官方 API

镜像会内置 OpenCode 全局默认配置 `/root/.config/opencode/config.json`，并预置 vendored 的 `superpowers` OpenCode 插件；仓库维护的全局 skills 会通过 `/root/.config/opencode/skills -> /opt/vendor/opencode/skills` 暴露给 OpenCode。

如果你在挂载到 `/workspace` 的项目根目录里放置 `opencode.json`，可以为该项目追加项目级配置。

`superpowers` 自带 skills 不需要手动加入 `skills.paths`，因为插件会在运行时自动注册它自己的 `skills/` 目录。

```bash
# .env 示例
CUSTOM_OPENAI_BASE_URL=https://your-host/v1
CUSTOM_OPENAI_API_KEY=your-api-key
CUSTOM_OPENAI_MODEL=your-model-name
```

## 自定义 Zsh

配置文件位于 `config/` 目录，修改后重新构建即可：

| 文件 | 说明 |
|------|------|
| `config/.zshrc` | Zsh 主配置 |
| `config/.p10k.zsh` | Powerlevel10k 主题 |
| `config/.zsh_plugins.txt` | Vendored 插件清单 |

```bash
# 修改配置后
docker compose up -d --build
```

## 项目结构

```
oh-my-openpod/
├── Dockerfile              # 容器镜像定义 (Ubuntu 24.04)
├── docker-compose.yml      # 编排配置 & 版本号
├── build/
│   ├── install-antidote.sh # 安装 Antidote
│   ├── install-btop.sh     # 安装 btop
│   ├── install-lazyvim.sh  # 安装默认 LazyVim starter 配置
│   ├── install-neovim.sh   # 安装 Neovim
│   ├── install-python-dev-tools.sh # 安装 pyright[nodejs] 与 ruff
│   ├── update-vendor-assets.sh # 更新 vendored release 包、插件快照和 OpenCode 插件包
│   ├── install-yazi.sh     # 安装 Yazi
│   └── install-zellij.sh   # 安装 Zellij
├── docs/
│   └── vendor-assets.md    # Vendored 资产来源与维护说明
├── .env.example            # 环境变量模板
├── config/
│   ├── nvim/
│   │   └── lua/plugins/python.lua # openpod 维护的 LazyVim Python overlay
│   ├── .zshrc              # Zsh 配置
│   ├── .p10k.zsh           # Powerlevel10k 配置
│   ├── .zsh_plugins.txt    # Vendored 插件清单
│   └── opencode.json       # 镜像内置 OpenCode 全局默认配置
├── tests/
│   └── run.sh              # 安装器与关键接线的 shell 级回归测试入口
└── vendor/
    ├── manifest.lock.json  # Vendored 资产清单
    ├── nvim/
    │   └── lazyvim-starter/ # Pinned LazyVim starter 快照
    ├── opencode/
    │   ├── packages/       # 需要保留原始结构的 OpenCode 插件包
    │   └── skills/         # 仓库直接维护的 OpenCode 全局 skills
    ├── releases/           # 构建脚本使用的固定 release 包
    └── zsh/                # Zsh 插件源码快照
```

## 参与贡献

欢迎提交 Issue 和 Pull Request！开发文档详见 [DEVELOPMENT.md](DEVELOPMENT.md)，vendored 资产说明详见 [docs/vendor-assets.md](docs/vendor-assets.md)。

## License

[MIT](LICENSE)
