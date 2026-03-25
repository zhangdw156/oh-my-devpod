# oh-my-openpod

一键搭建 **OpenCode + Git + uv + Zsh (Powerlevel10k)** 开发容器。  
克隆仓库，两条命令即可在任何装有 Docker 的机器上拥有一致的 AI 编程环境。

## 内置工具

| 工具 | 说明 |
|------|------|
| [OpenCode](https://github.com/anomalyco/opencode) | 终端 AI 编程助手 |
| [uv](https://github.com/astral-sh/uv) | 极速 Python 包管理器 |
| Git / curl / fzf / exa / bat | 常用命令行工具 |
| Zsh + Powerlevel10k + Antidote | 美观高效的 Shell 环境 |

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/<your-username>/oh-my-openpod.git
cd oh-my-openpod
```

### 2. 配置环境变量和 OpenCode（可选）

```bash
cp .env.example .env
# 编辑 .env，填入你的 API Key 等配置
```

配置 OpenCode 的 AI Provider：

```bash
cp opencode.json.example opencode.json
# 编辑 opencode.json，填入你的 Provider 信息
```

然后在 `.env` 中指向你的配置文件：

```
OPENCODE_CONFIG=./opencode.json
```

### 3. 构建并启动

```bash
# 构建镜像 + 启动容器（挂载 ~/projects 到 /workspace）
docker compose up -d --build

# 进入容器
docker compose exec openpod zsh
```

如需挂载其他目录，设置 `PROJECT_DIR` 环境变量：

```bash
PROJECT_DIR=/path/to/your/project docker compose up -d --build
```

或者写入 `.env` 文件：

```
PROJECT_DIR=/home/me/code
```

### 4. 在容器内使用

```bash
# 使用 opencode
opencode

# 使用 uv
uv init myproject
uv add requests

# 使用 git
git clone https://github.com/...
```

## 自定义 Zsh 配置

Zsh 配置文件位于 `config/` 目录：

- `config/.zshrc` — Zsh 主配置
- `config/.p10k.zsh` — Powerlevel10k 主题配置
- `config/.zsh_plugins.txt` — Antidote 插件列表

修改后重新构建镜像即可生效：

```bash
docker compose up -d --build
```

## 项目结构

```
oh-my-openpod/
├── Dockerfile              # 容器镜像定义
├── docker-compose.yml      # 编排配置
├── .env.example            # 环境变量模板
├── opencode.json.example   # OpenCode 配置模板
├── README.md
└── config/
    ├── .zshrc              # Zsh 配置
    ├── .p10k.zsh           # Powerlevel10k 配置
    └── .zsh_plugins.txt    # 插件列表
```
