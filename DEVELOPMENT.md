# 开发者文档

## 项目结构

```text
oh-my-devpod/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
│       └── release-omd.yml
├── README.md
├── README_EN.md
├── DEVELOPMENT.md
├── AGENTS.md
├── CLAUDE.md
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
│   ├── install-antidote.sh
│   ├── install-atuin.sh
│   ├── install-btop.sh
│   ├── install-claude-code.sh
│   ├── install-lazyvim.sh
│   ├── install-neovim.sh
│   ├── install-python-dev-tools.sh
│   ├── install-witr.sh
│   ├── install-yazi.sh
│   ├── install-zellij.sh
│   └── update-vendor-assets.sh
├── config/
├── docs/
├── tests/
├── vendor/
├── VERSION
└── versions.env
```

## 版本管理

仓库根目录 `VERSION` 文件是 `omd` release 的版本真源，格式为 `x.y.z.devN`（开发）或 `x.y.z`（正式发布）。

仓库根目录 `versions.env` 是工具版本的唯一真源。`build/update-vendor-assets.sh` 直接 source 此文件；`build/install-*.sh` 通过环境变量接收版本并保留回退默认值。更新工具版本时，先改 `versions.env`，然后同步相关 install 脚本回退默认值。`tests/test-versions-env.sh` 会验证这些值的一致性。

| 版本格式 | 含义 |
|----------|------|
| `x.y.z.devN` | 开发中，尚未发布 |
| `x.y.z` | 已发布的正式版本 |

## Issue 约定

- 使用 issue-driven development；实现提交必须引用对应 issue，例如 `Refs #103`。
- 新 issue 默认通过 GitHub Web UI 的 issue form 创建，统一走 `.github/ISSUE_TEMPLATE/`。
- `gh issue create` 不会自动套用 issue form；除非手动补齐相同标题和表单内容，否则不要直接用 CLI 裸建 issue。

## 发布实现约定

- 正式版 `omd` binary 由 `.github/workflows/release-omd.yml` 发布到 GitHub Releases。
- workflow 在 Ubuntu 24.04 上运行 `cargo build --release -p omd`。
- 发布产物包含 `omd-x86_64-unknown-linux-gnu.tar.gz` 和对应 `.sha256` 文件。
- `install/bootstrap.sh` 默认从 GitHub Releases 下载预编译 archive，而不是在用户机器上编译 Rust。

## 依赖安装约定

- `install/bootstrap.sh` 只负责平台检查、下载、安装并启动 `~/.local/bin/omd`。
- `crates/omd/` 负责 TUI、组件目录、状态展示和非交互检查命令。
- `modules/core/` 存放必装组件：Homebrew、zsh 环境、基础开发工具链。
- `modules/optional/` 存放可选 AI CLI 组件：Claude Code、Codex CLI、OpenCode、GitHub Copilot CLI、Gemini CLI。
- `modules/lib/common.sh` 存放共享 shell helper。
- `build/` 目录存放可复用安装脚本，例如 `install-neovim.sh`、`install-lazyvim.sh`、`install-python-dev-tools.sh`、`install-yazi.sh` 和 `install-zellij.sh`。
- `build/update-vendor-assets.sh` 用于刷新共享 release 包、LazyVim starter 快照和 Zsh 插件快照。
- `config/` 目录只存放共享配置，例如 shell 配置和 `nvim` overlay。
- `vendor/releases/` 存放固定 release 包，`vendor/nvim/` 存放默认 Neovim 配置快照，`vendor/zsh/` 存放默认 shell 使用的插件源码快照。
- `docs/environment-variables.md` 提供 `OHMYDEVPOD_*` 环境变量参考。

### Neovim / LazyVim 资产约定

- `neovim` 二进制通过官方 release tar 包维护在 `vendor/releases/neovim/`。
- `LazyVim/starter` 通过 pinned source snapshot 维护在 `vendor/nvim/lazyvim-starter/`。
- `pyright[nodejs]` 与 `ruff` 通过 `build/install-python-dev-tools.sh` 以 pinned PyPI 版本安装。
- `build/install-lazyvim.sh` 负责把 vendored starter 安装到标准 `nvim` 配置目录，并在首次接管非 oh-my-devpod 管理目录时自动备份 `config/data/state/cache`。
- `config/nvim/` 里的 overlay 会在 starter 安装完成后覆盖到目标配置目录。
- `vendor/nvim/lazyvim-starter/.oh-my-devpod-source-commit` 用于记录 pinned starter commit，便于安装元数据与后续升级。

### AI CLI 约定

- Claude Code 使用 `build/install-claude-code.sh` 安装原生二进制。
- Codex CLI 使用 `@openai/codex`。
- OpenCode 使用 `opencode-ai`。
- GitHub Copilot CLI 使用 `@github/copilot`。
- Gemini CLI 使用 `@google/gemini-cli`。
- npm-based 组件要求 `Node.js >=20`。
- 正常卸载只能移除软件本体、wrapper、symlink 或 oh-my-devpod 管理的 package prefix，不能删除用户配置、cache、auth 状态、token 或登录会话。

## 测试流程

```bash
bash tests/run.sh
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

关键专项测试：

```bash
bash tests/test-bootstrap.sh
bash tests/test-module-contracts.sh
bash tests/test-host-installer-layout.sh
bash tests/test-omd-release-workflow.sh
bash tests/test-vendor-assets-layout.sh
```

## 发布流程

```bash
# 1. 从 main 新建发布分支
git checkout main
git pull --ff-only origin main
git checkout -b release/x.y.z

# 2. 修改 VERSION 为正式版本（去掉 .devN 后缀）
git add VERSION
git commit -m "release: cut x.y.z"
git push -u origin release/x.y.z

# 3. 创建 PR 并 squash 合并
gh pr create --title "release: cut x.y.z" --body ""
gh pr merge --squash --delete-branch

# 4. 发布成功后，给 release commit 打 tag 并创建 GitHub Release
git checkout main
git pull --ff-only origin main
git tag vx.y.z
git push origin vx.y.z

# 5. 开始下一个版本的开发
git checkout -b chore/bump-version-to-next-dev
git add VERSION
git commit -m "chore: bump version to <next-version>.dev0"
git push -u origin chore/bump-version-to-next-dev
```

Tag 推送后，`.github/workflows/release-omd.yml` 会构建并上传 `omd` release artifact。
