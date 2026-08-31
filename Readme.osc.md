<p align="center">
  <img src="./docs/assets/omd-hero.svg" alt="oh-my-devpod — 面向 Ubuntu 开发工作站的依赖感知控制台" width="100%" />
</p>

<p align="center">
  <a href="https://gitee.com/zhangdw156/oh-my-devpod/releases"><img src="https://img.shields.io/github/v/release/zhangdw156/oh-my-devpod?style=flat-square&label=release&color=ea6847" alt="最新版本" /></a>
  <img src="https://img.shields.io/badge/Ubuntu-24.04-e95420?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04" />
  <img src="https://img.shields.io/badge/architecture-x86__64-172033?style=flat-square" alt="x86_64" />
  <img src="https://img.shields.io/badge/interface-Ratatui-58d6b0?style=flat-square" alt="Ratatui TUI" />
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-f2c14e?style=flat-square" alt="MIT License" /></a>
</p>

<p align="center">
  <a href="./README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <strong>把一台全新的 Ubuntu 主机，变成边界清晰、可审查的开发环境。</strong><br />
  一次可信安装、一份依赖计划，明确区分你的工具与项目管理的工具。
</p>

<p align="center">
  <a href="#快速开始"><strong>立即安装</strong></a>
  ·
  <a href="#组件目录"><strong>浏览组件</strong></a>
  ·
  <a href="#tui-工作流"><strong>了解流程</strong></a>
  ·
  <a href="#内建安全边界"><strong>查看安全设计</strong></a>
</p>

---

## 为什么选择 oh-my-devpod？

| 先计划，再修改 | 尊重已有环境 | 自动选择合适的软件源 |
| --- | --- | --- |
| 选择工具、审查解析后的依赖计划，再明确执行。 | 已有安装保持为外部组件，`omd` 不接管、也不删除。 | GitHub 使用上游源；Gitee 自动启用中科大 Homebrew 与清华 TUNA Python 镜像。 |

oh-my-devpod 是面向 **Ubuntu 24.04 x86_64** 的开发生产力工具管理器。
它将 Rust + Ratatui 交互界面与小型 Shell 生命周期模块结合：界面响应快速，
安装、更新和卸载过程则保持明确、可检查。

## 快速开始

### npm

使用 GitHub 官方上游源：

```bash
npm install --global oh-my-devpod
```

安装时选择国内镜像：

```bash
OHMYDEVPOD_SOURCE=gitee npm install --global oh-my-devpod
```

两种方式安装后的命令均为 `omd`。npm 包目前仅支持 Ubuntu 24.04 x86_64。

安装后可以随时切换组件下载源，无需重新安装 npm 包：

```bash
omd --source gitee
omd --source github
```

### Gitee · 国内镜像

```bash
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/bootstrap.sh \
  | OHMYDEVPOD_SOURCE=gitee bash
```

### GitHub · 官方上游源

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

bootstrap 会下载完整 release bundle，校验 SHA256 后安装到当前用户目录，
随后进入 TUI。安装完成后直接运行：

```bash
omd
```

> [!NOTE]
> 默认命令路径是 `~/.local/bin/omd`。如果该目录此前不在 `PATH` 中，请重启
> Shell。

## 组件目录

每个组件都可以独立选择；运行时依赖与安装阶段所需的提供者会自动补全。

| 分类 | 组件 | 用途 |
| --- | --- | --- |
| 基础 | **Linuxbrew**、**Zsh**、**uv**、**Micromamba** | 用户态软件包、Shell 与 Python/环境工具 |
| 开发 | **Git**、**GitHub CLI**、**Gitee CLI** | 版本控制与代码托管平台自动化 |
| 终端 | **ripgrep**、**fzf**、**bat**、**fd**、**jq**、**yq**、**Atuin**、**Zellij**、**Yazi**、**btop** | 搜索、结构化数据、导航、历史、会话、文件与系统状态 |
| 编辑器 | **Neovim**、**LazyVim** | 终端编辑器与受管编辑器配置 |
| 配置 | **Zsh productivity configuration** | Oh My Zsh、Powerlevel10k、补全、历史、模糊搜索与 `z` 目录跳转 |

例如，下列命令会为 Micromamba 与 LazyVim 生成计划，并自动把它们的提供者
排在前面：

```bash
omd --plan install micromamba lazyvim
```

```text
用户选择
   │
   ▼
components.toml ── 解析依赖 ── 审查有序计划 ── 执行组件模块
```

如果 Git、Neovim 或其他依赖已经由系统或用户安装，它可以满足依赖，但不会
因此被 oh-my-devpod 接管。

## TUI 工作流

界面把“发现与审查”和“实际修改”分开：

1. **选择动作**：安装、更新或卸载。
2. **选择组件**：查看缺失、受管、损坏或外部状态。
3. **审查计划**：安装时依赖在前，卸载时依赖者在前。
4. **明确执行**：运行任何模块前，会再次校验已审查的计划。

| 按键 | 操作 |
| --- | --- |
| `Tab` | 切换 install / update / uninstall |
| `↑` / `↓` 或 `j` / `k` | 移动 |
| `Space` | 选择或取消组件 |
| `Enter` | 审查，然后执行 |
| `Esc` | 返回或退出 |
| `q` | 退出 |

## CLI 控制

可以使用 TUI 完成交互操作，也可以使用 CLI 检查状态或自动化执行。

```bash
# 清单与元数据
omd --list-components
omd --status
omd --version

# 只生成计划，不修改主机
omd --plan install micromamba lazyvim
omd --plan-current uninstall lazyvim neovim
omd --dry-run

# 针对当前主机状态执行
omd --execute install ripgrep fzf
```

### 自更新与全局源切换

```bash
omd --update           # 使用已保存的来源更新
omd --update --github  # 更新，并切换到官方上游源
omd --update --gitee   # 更新，并切换到国内镜像
omd --source github    # 只切源，不更新 omd
omd --source gitee     # 只切源，不更新 omd
```

| 命令 | 持久化效果 |
| --- | --- |
| `omd --update` | 使用 `~/.config/oh-my-devpod/source`；配置缺失或无效时回退到 GitHub。 |
| `omd --update --github` | 使用 GitHub release，并将受管 Homebrew、Micromamba、uv、pip 源切换到上游。 |
| `omd --update --gitee` | 使用 Gitee release，并切换到中科大 Homebrew 与清华 TUNA Micromamba、uv、pip 镜像。 |
| `omd --source github` | 不更新 `omd`，将已经安装且由 OMD 管理的包管理器和后续组件操作切换到官方上游源。 |
| `omd --source gitee` | 不更新 `omd`，将已经安装且由 OMD 管理的包管理器和后续组件操作切换到国内镜像。 |

`--github` 与 `--gitee` 互斥。即使当前版本已经是最新，显式源切换仍会生效。
自更新只替换通过 SHA256 校验的 release bundle，不会打开 TUI，也不会更新
已安装组件。下载、校验或激活失败时，当前版本与原来源配置保持不变。

npm 管理的安装应通过 npm 更新：

```bash
npm update --global oh-my-devpod
```

npm 安装的 `omd --update` 会被明确拒绝，避免 npm 与内建更新器同时管理同一
安装。来源切换由 `omd --source` 独立完成，不依赖 npm 是否实际安装了新版本。

来源切换会立即作用于 OMD 启动的组件操作。已经运行的交互式 shell 需要重新
启动，或重新
`source ${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod}/env`，
才能刷新镜像环境变量。

对于已经安装且由 OMD 管理的工具，切源还会同步修改它们的原生持久化配置：

- 受管 Linuxbrew：切换 `brew`、`homebrew/core` remote，并更新
  `${HOMEBREW_PREFIX}/etc/homebrew/brew.env`
- 受管 uv：更新 `${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml`
- 受管 Micromamba：更新 `~/.mambarc`
- 受管 Python 环境工具：更新用户级 `pip.conf`

切回 GitHub 时只删除 OMD 生成的文件。已有配置如果属于用户或已被修改，
OMD 不会覆盖，而是终止切源并整体回滚。已经安装的包和环境会原样保留，
不会为了切源而重新安装。

受管 Zsh 会初始化 Mamba shell hook，但不会覆盖 `MAMBA_ROOT_PREFIX`；
通过 Homebrew 安装的 Mamba 会继续使用其实际版本对应的 Cellar root。
它还会启用 Oh My Zsh 内置的 `z` 插件，提供基于访问频率和最近使用情况的
目录跳转。
从 0.14.1 或更早版本升级后，需要执行一次 `omd --execute update zsh-config`
并重新启动 shell。

Gitee CLI 组件会把官方最新的、经过 SHA256 校验的 Linux release 安装到
`~/.local/bin`。更新和卸载只管理该二进制，不会删除 `~/.config/gitee`、
自定义 `GITEE_CONFIG_DIR`、Agent Skills 或登录状态。

## 架构

```text
GitHub / Gitee
      │  版本化归档 + SHA256
      ▼
install/bootstrap.sh
      │  激活 ~/.local/bin/omd
      ▼
┌──────────────────────── Rust ────────────────────────┐
│  Ratatui 界面 → 组件目录 → 依赖规划器 → 生命周期执行器 │
└──────────────────────────┬───────────────────────────┘
                           │ status / managed / install
                           │ update / uninstall
                           ▼
┌──────────────────────── Shell ───────────────────────┐
│  组件模块 → 工具、配置、所有权标记                    │
└──────────────────────────────────────────────────────┘
```

| 路径 | 职责 |
| --- | --- |
| `components.toml` | 组件与依赖关系的唯一真源 |
| `install/bootstrap.sh` | 双来源、带校验的安装入口 |
| `install/update.sh` | 事务式自更新与来源切换 |
| `crates/omd/` | Rust TUI、目录校验、依赖规划与执行 |
| `modules/core/`、`modules/tools/` | 组件生命周期实现 |
| `modules/lib/` | 共享所有权与安全原语 |
| `npm/` | npm 启动器、安装来源选择与包元数据 |
| `build/`、`vendor/`、`config/` | release 组装与固定版本资产 |
| `VERSION` | `omd` release 版本真源 |

## 内建安全边界

- **所有权控制卸载**：只删除带有 oh-my-devpod 所有权标记的产物。
- **外部安装始终属于外部**：识别已有工具，但绝不自动接管或删除。
- **依赖安全计划**：如果卸载会破坏仍在使用的依赖者，操作会被阻止。
- **保护基础设施**：Linuxbrew 不进入普通卸载流程。
- **保护用户配置**：接管 Zsh 或 Neovim 前备份原配置；卸载时保留用户数据、
  缓存和备份。
- **校验 release**：归档必须通过 SHA256 与 bundle 结构校验后才能激活。
- **事务式更新**：自更新失败时，来源配置与受管 Homebrew remote 会回滚。

默认受管路径：

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/releases/<version>/
~/.local/share/oh-my-devpod/opt/
~/.local/state/oh-my-devpod/
~/.config/oh-my-devpod/
```

## 开发

组件目录是声明式的；每个模块都实现统一的
`status` / `managed` / `install` / `update` / `uninstall` 契约。

```bash
bash tests/run.sh
cargo fmt --all -- --check
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --list-components
cargo run -p omd -- --plan install micromamba lazyvim
git diff --check
```

构建 release bundle：

```bash
bash build/package-omd.sh
bash build/package-npm.sh dist/omd-x86_64-unknown-linux-gnu.tar.gz
```

模块边界、所有权规则、镜像行为和 release 维护说明见
[`DEVELOPMENT.md`](./DEVELOPMENT.md)；npm 首次发布流程见
[`docs/npm-release.md`](./docs/npm-release.md)。

---

<p align="center">
  <sub>为克制而明确的终端而构建：快速部署、透明变更、安全撤销。</sub>
</p>
