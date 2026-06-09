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

## 一键启动 `omd`

首次运行：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

`install/bootstrap.sh` 只做最小引导：

1. 检测当前系统是否为 Ubuntu 24.04。
2. 检测 `sudo`，必要时让用户交互输入 sudo 密码。
3. 下载预编译 Rust TUI binary。
4. 安装到 `~/.local/bin/omd`。
5. 立即启动 `omd`。

后续再次运行：

```bash
omd
```

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

## 项目结构

```text
oh-my-devpod/
├── install/
│   ├── bootstrap.sh
│   └── setup.sh
├── crates/
│   └── omd/
├── modules/
│   ├── core/
│   ├── optional/
│   └── lib/
├── build/
├── config/
├── vendor/
├── tests/
├── VERSION
└── versions.env
```

- `install/bootstrap.sh`：公开的一行安装入口。
- `crates/omd/`：Rust + Ratatui + Crossterm TUI。
- `modules/`：组件生命周期接口，支持 `status` / `install` / `update` / `uninstall`。
- `build/`：可复用安装脚本和 vendored asset 刷新脚本。
- `vendor/`：zsh、Neovim 和 release 资产快照。
- `VERSION`：`omd` 发布版本的仓库级真源。

## 开发验证

```bash
bash tests/run.sh
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

## 说明

- `omd` 是长期命令；`curl | bash` 只负责安装并启动它。
- 当前第一版只支持 Ubuntu 24.04。
- 正常卸载不会删除用户配置、cache、auth 状态或 token。
- 首次执行 `nvim` 仍然需要联网，因为 `lazy.nvim` 会按需拉取插件。
