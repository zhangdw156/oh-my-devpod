<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Rust_TUI-Productivity_Tools-2496ED?style=for-the-badge" alt="Rust TUI"/>
  <img src="https://img.shields.io/badge/Zsh-Neovim-4EAA25?style=for-the-badge" alt="Zsh and Neovim"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>一个 curl 入口，一个依赖感知的 Linux 开发工具管理器</strong><br/>
  在 Ubuntu 24.04 上选择、安装、更新和安全卸载常用生产力工具。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> | 中文
</p>

---

## 快速开始

可以访问 GitHub：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

无法访问 GitHub、使用国内源：

```bash
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/bootstrap.sh \
  | OHMYDEVPOD_SOURCE=gitee bash
```

bootstrap 会下载完整、经过 SHA256 校验的 `omd` release bundle，安装到用户目录并进入 TUI。后续直接运行：

```bash
omd
```

Gitee 模式会持久化 `cn` 镜像配置。后续组件安装会自动使用 USTC Homebrew 镜像和 TUNA Python 索引；GitHub 模式保持上游源。

## 可选工具

所有工具均可单独选择，依赖会自动补全：

| 分类 | 组件 |
| --- | --- |
| 基础 | Linuxbrew、Zsh、uv |
| 开发 | Git |
| 终端 | ripgrep、fzf、bat、fd、jq、Atuin、Zellij、Yazi、btop |
| 编辑器 | Neovim、LazyVim |
| 配置 | Zsh productivity configuration |

依赖示例：

```text
LazyVim ──> Neovim
        └─> Git ──(安装时需要)──> Linuxbrew

Zsh configuration ──> Zsh
                  ├─> fzf
                  └─> Atuin
```

如果依赖已经由系统或用户安装，`omd` 会把它识别为外部组件，不重复安装，也不会在卸载时删除它。

## TUI 操作

```text
Tab                 切换 install / update / uninstall
↑ / ↓ 或 j / k      移动
Space               选择组件
Enter               查看计划并执行
Esc                 返回或退出
q                   退出
```

执行前会展示解析后的完整计划。安装按“依赖在前”执行；卸载按“依赖者在前”执行。如果仍有已安装组件依赖某个工具，卸载会被阻止。

## 安全边界

- 只卸载带有 oh-my-devpod 所有权标记的组件。
- 不接管或删除外部安装。
- Linuxbrew 不允许通过普通卸载流程删除。
- 接管 Zsh 或 Neovim 配置前会保留原配置。
- 卸载配置时保留用户数据、缓存和备份。
- release archive 在启用前必须通过 SHA256 校验。

默认路径：

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/releases/<version>/
~/.local/share/oh-my-devpod/opt/
~/.local/state/oh-my-devpod/
~/.config/oh-my-devpod/
```

## 命令行接口

```bash
omd --list-components
omd --status
omd --plan install lazyvim
omd --plan uninstall lazyvim neovim
omd --execute install ripgrep fzf
omd --version
```

## 项目结构

```text
oh-my-devpod/
├── components.toml
├── install/bootstrap.sh
├── crates/omd/
├── modules/
│   ├── core/
│   ├── tools/
│   └── lib/
├── build/
├── config/
├── vendor/
├── tests/
├── VERSION
└── versions.env
```

- `components.toml`：组件、分类、依赖和模块路径的唯一目录。
- `crates/omd/`：Rust + Ratatui TUI、依赖计划和模块执行器。
- `modules/`：`status` / `managed` / `install` / `update` / `uninstall` 生命周期。
- `build/`：release bundle 和 vendored 工具安装脚本。
- `vendor/`：可复现安装所需的固定版本资产。
- `VERSION`：`omd` release 版本真源。

## 开发验证

```bash
bash tests/run.sh
cargo fmt --all -- --check
cargo test -p omd
cargo run -p omd -- --list-components
cargo run -p omd -- --plan install lazyvim
git diff --check
```

当前第一版仅支持 Ubuntu 24.04 x86_64。
