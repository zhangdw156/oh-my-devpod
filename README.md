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
| **Shell** | Zsh + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) + [Antidote](https://github.com/mattmc3/antidote) | 语法高亮、自动补全、Git 状态提示 |
| **Terminal** | [Zellij](https://github.com/zellij-org/zellij) | 终端多路复用器，适合长时间开发会话 |
| **TUI** | [Yazi](https://yazi-rs.github.io/) | 现代化终端文件管理器，支持快速预览和目录跳转 |
| **Monitor** | [btop](https://github.com/aristocratos/btop) | 终端资源监控面板，便于查看容器内 CPU、内存和进程状态 |
| **CLI** | Git / curl / fzf / eza / bat / fd / rg / file / vim | 现代化命令行工具集 |
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
cp opencode.json.example opencode.json  # 配置 AI Provider
```

`.env` 支持官方 API 和自部署的 OpenAI / Anthropic 兼容接口，详见 [.env.example](.env.example)。

### 3. 方式 A：本地构建并启动

```bash
# 默认挂载 ~/projects
docker compose up -d --build

# 挂载指定项目
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

本地构建仍需要构建环境能访问 GitHub：

- 下载 Antidote、btop、Yazi 和 Zellij
- 预拉取 `.zsh_plugins.txt` 中列出的插件仓库

### 4. 方式 B：直接使用 GHCR 预构建镜像

如果你不想在本地构建，也可以直接使用发布到 GitHub Container Registry 的镜像：

```bash
# 拉取最新正式版
docker pull ghcr.io/zhangdw156/oh-my-openpod:latest

# 或拉取指定版本
docker pull ghcr.io/zhangdw156/oh-my-openpod:0.1.0

# 直接启动并进入容器
docker run --rm -it \
  --name oh-my-openpod \
  --network host \
  -v "${PROJECT_DIR:-$HOME/projects}:/workspace" \
  -v "$(pwd)/opencode.json:/root/.config/opencode/config.json:ro" \
  --env-file .env \
  ghcr.io/zhangdw156/oh-my-openpod:latest
```

对于服务器环境，更推荐这种方式：无需本地 build，也不用关心构建时访问 GitHub 的依赖下载。

镜像地址：

```text
ghcr.io/zhangdw156/oh-my-openpod
```

### 5. 进入容器，开始工作

如果你使用的是 `docker compose` 方式，可以这样进入容器：

```bash
docker compose exec openpod zsh
```

```
root@hostname /workspace main ❯ opencode   # AI 编程助手
root@hostname /workspace main ❯ zellij     # 终端多路复用会话
root@hostname /workspace main ❯ y          # Yazi 文件管理器（退出时同步 cwd）
root@hostname /workspace main ❯ btop       # 资源监控面板
root@hostname /workspace main ❯ uv run ... # Python 项目
root@hostname /workspace main ❯ git status  # Git 操作
```

`zellij` 已预装，但默认不会自动接管 shell；按需手动执行 `zellij` 即可进入会话。
`y` 是 `yazi` 的 shell wrapper；退出 Yazi 后会把当前目录同步回 shell。

## 支持自部署 AI 服务

通过 `.env` + `opencode.json` 配置，可以对接：

- **OpenAI 兼容接口**：vLLM / Ollama / LiteLLM / 硅基流动 等
- **Anthropic 兼容接口**：自部署 Claude / AWS Bedrock 代理 等
- **官方服务**：OpenAI / Anthropic 官方 API

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
| `config/.zsh_plugins.txt` | Antidote 插件列表 |

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
│   ├── install-yazi.sh     # 安装 Yazi
│   └── install-zellij.sh   # 安装 Zellij
├── .env.example            # 环境变量模板
├── opencode.json.example   # OpenCode AI Provider 配置模板
├── config/
│   ├── .zshrc              # Zsh 配置
│   ├── .p10k.zsh           # Powerlevel10k 配置
│   └── .zsh_plugins.txt    # 插件列表
└── vendor/
    └── .gitkeep            # 预留给未来的 vendored 依赖
```

## 参与贡献

欢迎提交 Issue 和 Pull Request！开发文档详见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## License

[MIT](LICENSE)
