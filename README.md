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
# --recurse-submodules 会同步拉取 vendor/antidote
git clone --recurse-submodules https://github.com/<your-username>/oh-my-openpod.git
cd oh-my-openpod
```

> 如果已经克隆但忘记加 `--recurse-submodules`，补执行一次：
> ```bash
> git submodule update --init --recursive
> ```

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

## 更新 Antidote 版本

Antidote 以 git submodule 的形式固定在 `vendor/antidote`，版本由 `.gitmodules` 追踪。

```bash
# 拉取 antidote 最新版本并更新 submodule 引用
git submodule update --remote vendor/antidote

# 提交新的版本锁定
git add vendor/antidote
git commit -m "chore: bump antidote to latest"
```

重新构建镜像即可使用新版本：

```bash
docker compose up -d --build
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
├── .gitmodules             # submodule 版本锁定
├── opencode.json.example   # OpenCode 配置模板
├── README.md
├── config/
│   ├── .zshrc              # Zsh 配置
│   ├── .p10k.zsh           # Powerlevel10k 配置
│   └── .zsh_plugins.txt    # 插件列表
├── VERSION                 # 当前开发版本号
└── vendor/
    └── antidote/           # Zsh 插件管理器 (git submodule, 固定到 v2.0.2)
```

## 版本管理与发布流程

当前版本号记录在 `VERSION` 文件中，开发中的版本以 `-dev` 后缀标识。

**版本状态示例：**

| `VERSION` 内容 | 含义 |
|----------------|------|
| `0.1.0-dev` | 0.1.0 开发中，尚未发布 |
| `0.1.0` | 已发布的正式版本 |
| `0.2.0-dev` | 0.2.0 开发中 |

**发布一个版本：**

```bash
# 1. 将 VERSION 改为正式版本号（去掉 -dev）
echo "0.1.0" > VERSION
git add VERSION
git commit -m "chore: release v0.1.0"

# 2. 打 git tag（触发 Docker Hub 自动构建）
git tag v0.1.0
git push origin main --tags
```

**发布后开始下一个版本的开发：**

```bash
echo "0.2.0-dev" > VERSION
git add VERSION
git commit -m "chore: begin development of v0.2.0"
```

**升级 Antidote 版本：**

```bash
cd vendor/antidote
git fetch --tags
git checkout <new-tag>   # 例如 v2.1.0
cd ../..
git add vendor/antidote .gitmodules
git commit -m "chore: bump antidote to <new-tag>"
```
