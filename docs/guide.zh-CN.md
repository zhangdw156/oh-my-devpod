# OMD 使用指南

[项目首页](../Readme.osc.md) · [English](guide.md)

## 系统依赖

OMD 支持 x86_64 架构的 Ubuntu 20.04、22.04、24.04 和 26.04。新服务器缺少 Linuxbrew 所需的系统包时，由管理员安装一次，所有账号都能使用。

```bash
sudo apt-get update
sudo apt-get install -y build-essential procps curl file git ca-certificates
```

在 20.04 和 22.04 上，显式运行 `uv venv --python /usr/bin/python3` 使用系统 Python 时，还需要 `python3-distutils`。

## 安装

使用自己的账号，从以下方式中选择一种。bootstrap 会下载发行包、校验 SHA256、安装到 `~/.local/bin/omd`，然后自动打开 TUI。之后运行 `omd` 即可再次打开。如果当前终端还找不到刚创建的命令目录，可直接运行 `~/.local/bin/omd`。

**Gitee 国内镜像**

```bash
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/bootstrap.sh \
  | OHMYDEVPOD_SOURCE=gitee bash
```

**GitHub 上游源**

默认先从 GitHub 下载，获取不到通过校验的发行包时再尝试 Gitee。

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

**npm**

使用 Node.js 18 或更高版本、且当前用户可以写入 npm 全局安装目录时，二选一安装，再运行 `omd`。

```bash
OHMYDEVPOD_SOURCE=gitee npm install --global oh-my-devpod
```

```bash
npm install --global oh-my-devpod
```

npm 包已包含 OMD 运行所需的文件。`OHMYDEVPOD_SOURCE` 指定 OMD 安装组件时使用的源，npm 获取这个包时使用自己的 registry。

### 仅能访问国内镜像的网络

系统 APT 源需指向可访问的 Ubuntu 镜像。国内配置从 Gitee 获取 OMD 发行包，从中科大 USTC 获取 Homebrew 的 Git 仓库、API 数据和二进制包，从清华 TUNA 获取 PyPI 和 Conda 包，从 npmmirror 下载 uv 管理的 Python 解释器。随包提供的 LazyVim 插件可离线启动。使用 `gh` 登录或操作 GitHub PR 仍需访问 GitHub。用户额外添加的编辑器插件、外部工具和 Git 仓库使用各自配置的地址。[LazyVim 离线配置](vendor-assets.md#lazyvim-in-the-china-profile)

## TUI 与 CLI

运行 `omd`。在 Linuxbrew 下展开 Neovim 可以看到 LazyVim，展开 Zsh 可以看到托管配置。每行的选择和安装状态独立。例如，选择安装 LazyVim 时，计划会补上缺失的 Git 和 Neovim。筛选可以匹配名称、ID、类别或简介，并自动展开匹配项的祖先节点。

| 按键 | 操作 |
| --- | --- |
| `Tab` | 在安装、更新、卸载之间切换，切换时清除本次选择。 |
| `↓` / `j`、`↑` / `k` | 向下或向上移动。 |
| `→` / `l`、`←` / `h` | 展开或折叠分支。在叶子节点或已折叠节点上向左会回到父节点。 |
| `/` | 输入筛选词，`Backspace` 删除字符，`Enter` 保留筛选，`Esc` 清除。 |
| `Space` | 选中或取消当前组件。 |
| `Enter` | 打开计划。在有效计划上再次按下才执行。 |
| `Esc` | 从计划返回、清除当前筛选或退出列表。 |
| `q` | 从列表或计划退出。 |

CLI 接受组件目录中的 ID。查询和预览均可在修改系统前使用。

| 命令 | 用途 |
| --- | --- |
| `omd --list-components` | 列出组件 ID、依赖类型、安装范围与卸载支持。 |
| `omd --status` | 查看哪些组件缺失、由外部安装、由 OMD 管理或需要修复。 |
| `omd --version` | 显示当前运行的 OMD 版本。 |
| `omd --plan install micromamba lazyvim` | 按全新账号的状态预览安装顺序。 |
| `omd --plan-current uninstall lazyvim neovim` | 按当前账号的真实状态预览卸载。 |
| `omd --dry-run` | 预览安装整个目录，包括各模块将执行的操作。 |
| `omd --execute install ripgrep fzf` | 安装指定工具和缺失的依赖。 |
| `omd --execute update zsh-config` | 刷新已经托管的 Zsh 配置。 |

安装先处理依赖，卸载先处理依赖目标的组件。如果仍有保留的组件需要目标，卸载会被阻止。执行前 OMD 会获取锁并再次核对计划。

## 切换软件源

| 命令 | 使用场景 |
| --- | --- |
| `omd --source gitee` | 将已托管工具和后续组件操作切到国内镜像，适用于 bootstrap 与 npm 安装。 |
| `omd --source github` | 将这些工具和后续组件操作切回上游源。 |
| `omd --update` | 从 `~/.config/oh-my-devpod/source` 保存的来源更新 bootstrap 安装的 OMD。配置缺失或无效时使用 GitHub。 |
| `omd --update --gitee` | 从 Gitee 更新 OMD，同时切到国内镜像。已是最新版本时切源也会生效。 |
| `omd --update --github` | 从 GitHub 更新 OMD，同时切到上游源。已是最新版本时切源也会生效。 |

每次操作选一个源。切换对 OMD 启动的组件进程立即生效。打开新的托管 shell 即可使用新配置，也可在当前 shell 中运行 `source "${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod}/env"`。

OMD 会同步更新已托管工具的原生配置。Linuxbrew 使用 `brew`、`homebrew/core` 的 Git remote 和 `~/.linuxbrew/etc/homebrew/brew.env`。默认 XDG 路径下，uv 使用 `~/.config/uv/uv.toml`，Micromamba 使用 `~/.mambarc`，pip 使用 `~/.config/pip/pip.conf`。切回上游时会移除 OMD 生成的镜像设置。遇到用户已有的配置或修改过的托管文件冲突时，切换中止并恢复原来的配置。已经安装的包和环境继续可用。[配置目录与环境变量](environment-variables.md)

## 更新

bootstrap 安装的用户运行 `omd --update`。自更新只替换 OMD 发行包，下载和内容校验通过后才激活。下载、校验或激活失败时保留原版本与原软件源。[从其他来源更新](#切换软件源)

npm 安装的用户运行 `npm update --global oh-my-devpod`。npm 管理包版本，运行 `omd --update` 会提示改用 npm。更新会沿用已选的组件源。更新单个工具时，在 TUI 选择 **update**，或在 `omd --execute update` 后附上组件 ID。

### 从旧版本升级

- 如果 0.14.1 报 `previous_dir: unbound variable`，新版本可能已激活。先用 `omd --version` 查看，再执行一次 `omd --update`。从 0.14.4 起，激活由通过校验的新版 bootstrap 完成。
- 托管 Zsh 配置来自 0.14.1 或更早版本时，执行 `omd --execute update zsh-config` 并打开新的 shell。
- 如果旧安装器无法识别当前发行包，请用自己的账号重新运行当前 bootstrap，再安装个人 Linuxbrew。[安装命令](#安装)

## 多人服务器

每个账号自行安装 OMD。在 TUI 中选择 Linuxbrew，或运行 `omd --execute install linuxbrew`。下次登录 Bash 或 Zsh 时会自动找到个人 Brew 的工具。该账号的 Cellar 中已有的包可以满足依赖，所有权仍归原安装者。全机共享的 Brew 继续由原管理员负责。在 `~/.linuxbrew` 下，要求 Homebrew 标准 Linux 前缀的二进制包可能需要从源码构建。

| 默认位置 | 存放内容 |
| --- | --- |
| `~/.linuxbrew/` | 个人 Brew、Cellar 和镜像配置 |
| `~/.local/bin/omd` | bootstrap 安装的活动命令入口 |
| `~/.local/share/oh-my-devpod/releases/<version>/` | 按版本存放的 bootstrap 发行包 |
| `~/.local/share/oh-my-devpod/zsh/` | 托管的 Zsh 主题和插件 |
| `~/.local/state/oh-my-devpod/` | 组件所有权标记、执行锁、配置备份 |
| `~/.config/oh-my-devpod/` | 软件源、安装路径、shell 环境配置 |
| `~/.cache/oh-my-devpod/` | 下载的发行包缓存 |

### SSH 登录与托管 Zsh

如果升级 OMD 之前已经托管 Zsh 和配置，请执行一次 `omd --execute update zsh-config`，为现有配置加入登录入口。

安装 OMD 托管的 Zsh 和 `zsh-config` 后，用 Bash 账号新建交互式 SSH 会话会自动进入 `~/.linuxbrew/bin/zsh`，并加载托管的 `~/.zshrc`。远程命令和文件传输继续走原有流程。`echo "$ZSH_VERSION"` 显示当前 Zsh 进程的版本，`$SHELL` 表示账号设置的登录 shell，可能仍是 `/bin/bash`。要立即在当前终端使用 Zsh，可运行 `exec "$HOME/.linuxbrew/bin/zsh" -l`。

OMD 按 Bash 的读取顺序，在 `.bash_profile`、`.bash_login`、`.profile` 中第一个适用的启动文件加入入口，卸载配置时移除。软链接和其他账号所有的启动文件会跳过。OMD 在 `~/.zshenv` 中加入一行，补全初始化交给 Oh My Zsh，权限不安全的目录会被排除。`z` 按访问频率和最近使用情况跳转目录。Mamba 的 shell hook 沿用已有 `MAMBA_ROOT_PREFIX`，也支持 Homebrew 安装的 Mamba 使用版本对应的 Cellar 路径。

托管 Zsh 保留已有 `EDITOR` 或 `VISUAL`。两者都未设置且能找到 Neovim 时才默认使用 `nvim`。安装 Zellij 后可用 `zj`，安装 Yazi 后可用 `y` 打开文件管理器并在退出时切换到最后浏览的目录。磁盘占用工具 `dust` 可以单独选装，安装后用 `dust .` 查看当前目录的占用树。

### 卸载与个人数据

卸载组件需要所有权标记匹配，Linuxbrew 受保护。OMD 在替换原有 Zsh 和 Neovim 配置前会先备份。卸载 LazyVim 时保留配置备份、编辑器数据、状态和缓存。Gitee CLI 组件将校验过 SHA256 的官方发行版装到 `~/.local/bin/gitee`。更新或卸载会保留 `~/.config/gitee`、自定义 `GITEE_CONFIG_DIR`、Agent Skills 和登录状态。
