<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Rust_TUI_Host_Installer-2496ED?style=for-the-badge" alt="Rust TUI Host Installer"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>一个 curl 入口，一个 Rust TUI 安装器</strong><br/>
  在 Ubuntu 24.04 宿主机上安装和管理 AI 开发工具链。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

---

## 一键启动 `omd` 安装器

oh-my-devpod 的主产品形态正在迁移为 **Ubuntu 24.04 宿主机安装器**。首次运行只需要一条命令：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

这个 bootstrap 脚本只负责：

1. 检测当前系统是否为 Ubuntu 24.04。
2. 检测 `sudo`，必要时让用户交互输入 sudo 密码。
3. 从 GitHub Releases 下载预编译 Rust TUI binary。
4. 安装到 `~/.local/bin/omd`。
5. 立即启动 `omd`。

后续再次运行：

```bash
omd
```

同一个 TUI 用于首次安装、更新、补装和卸载可选组件。

## 安装模型

`omd` 管理两类组件：

- **必装组件**：Homebrew、zsh 环境、基础开发工具链。
- **可选组件**：Claude Code、Codex CLI、OpenCode、GitHub Copilot CLI、Gemini CLI。

卸载可选组件时，`omd` 只删除软件本体、wrapper、symlink 或 oh-my-devpod 管理的 package prefix；不会删除用户配置、cache、auth 状态、token 或登录会话。

默认用户级路径：

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/
~/.local/state/oh-my-devpod/logs/
~/.cache/oh-my-devpod/
```

## 当前实现状态

- `install/bootstrap.sh` 是新的 `curl | bash` 入口。
- `crates/omd/` 是 Rust + Ratatui + Crossterm TUI。
- `modules/` 提供 `status` / `install` / `update` / `uninstall` 生命周期接口。
- 旧的 `install/setup.sh` 仍暂时保留，作为迁移期间的兼容脚本。

## Legacy Docker 用法

Docker / 多 flavor 镜像仍在仓库中保留为 legacy 路径，但不再是新的主产品方向。镜像版本仍由仓库根目录 `VERSION` 管理；compose 路径仍支持 `IMAGE_VERSION` 覆盖。



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

## 项目结构

```text
oh-my-devpod/
├── install/
│   └── bootstrap.sh
├── crates/
│   └── omd/
├── modules/
│   ├── core/
│   └── optional/
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
└── vendor/
```

## 验证

开发改动后优先执行：

```bash
bash tests/run.sh
cargo test -p omd
```

Legacy Docker smoke test 示例：

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help | head -1
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

## 说明

- `omd` 是新的主入口，`curl | bash` 只负责安装并启动它
- `devpod` / 多 flavor 镜像是 legacy 路径，保留到迁移完成
- legacy `openpod`、`claudepod`、`codexpod`、`copilotpod`、`geminipod` 仍使用同一版本号发布
- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件
