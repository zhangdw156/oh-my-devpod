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
随后进入 TUI。首次安装后直接运行：

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
| 开发 | **Git** | 版本控制 |
| 终端 | **ripgrep**、**fzf**、**bat**、**fd**、**jq**、**Atuin**、**Zellij**、**Yazi**、**btop** | 搜索、导航、历史、会话、文件与系统状态 |
| 编辑器 | **Neovim**、**LazyVim** | 终端编辑器与受管编辑器配置 |
| 配置 | **Zsh productivity configuration** | Oh My Zsh、Powerlevel10k、补全、历史与模糊搜索 |

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
```

| 命令 | 持久化效果 |
| --- | --- |
| `omd --update` | 使用 `~/.config/oh-my-devpod/source`；配置缺失或无效时回退到 GitHub。 |
| `omd --update --github` | 使用 GitHub release，并将受管 Homebrew、Micromamba、uv、pip 源切换到上游。 |
| `omd --update --gitee` | 使用 Gitee release，并切换到中科大 Homebrew 与清华 TUNA Micromamba、uv、pip 镜像。 |

`--github` 与 `--gitee` 互斥。即使当前版本已经是最新，显式源切换仍会生效。
自更新只替换通过 SHA256 校验的 release bundle，不会打开 TUI，也不会更新
已安装组件。下载、校验或激活失败时，当前版本与原来源配置保持不变。

来源切换会立即作用于 OMD 启动的组件操作。已经运行的交互式 shell 需要重新
启动，或重新
`source ${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod}/env`，
才能刷新镜像环境变量。

受管 Zsh 会初始化 Mamba shell hook，但不会覆盖 `MAMBA_ROOT_PREFIX`；
通过 Homebrew 安装的 Mamba 会继续使用其实际版本对应的 Cellar root。
从 0.14.1 或更早版本升级后，需要执行一次 `omd --execute update zsh-config`
并重新启动 shell。

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
```

模块边界、所有权规则、镜像行为和 release 维护说明见
[`DEVELOPMENT.md`](./DEVELOPMENT.md)。

---

<p align="center">
  <sub>为克制而明确的终端而构建：快速部署、透明变更、安全撤销。</sub>
</p>
