# 开发者文档

## 架构边界

oh-my-devpod 是 Ubuntu 24.04 开发生产力工具管理器。`omd` 负责交互、
依赖规划和模块编排；Shell 模块负责单个工具的状态探测与生命周期操作。

```text
components.toml            组件目录与依赖真源
install/bootstrap.sh       GitHub/Gitee release bootstrap
install/update.sh          transactional self-update and source switching
crates/omd/                Rust TUI、planner、runner
modules/core/              Linuxbrew、Zsh、uv
modules/tools/             独立生产力工具与配置
modules/lib/common.sh      所有权、安全路径和包管理公共逻辑
build/package-omd.sh       完整 runtime bundle 打包
build/package-npm.sh       从同一 runtime bundle 生成 npm 包
build/install-*.sh         vendored 二进制/配置安装器
config/                    项目维护的配置 overlay
npm/                       npm launcher、来源选择与 package metadata
vendor/                    固定版本 release 与配置快照
tests/                     Shell 与 Rust 回归测试
VERSION                    release 版本真源
versions.env               vendored 工具版本真源
```

项目不提供编程助手 CLI 安装，也不维护由 uv 管理的额外 Python 工具。

## 组件清单

`components.toml` 的每个组件必须声明：

- `id`
- `name`
- `description`
- `category`
- `module`
- `requires`：运行时组件依赖
- `install_requires`：仅安装/更新时需要的提供者
- `uninstall`：是否支持普通卸载

`requires` 与 `install_requires` 必须分开。例如 Git 本身不要求
Linuxbrew 才能运行，但本项目通过 Linuxbrew 安装 Git，因此 Linuxbrew
属于 `install_requires`。

新增组件时必须同时增加模块、清单项和测试。模块路径必须位于
`modules/` 内，并具备可执行权限。

## 模块契约

每个模块必须实现：

```text
status
managed
install [--dry-run]
update [--dry-run]
uninstall [--dry-run]
```

- `status`：组件是否存在。
- `managed`：当前安装是否由 oh-my-devpod 管理。
- 外部安装不得被自动接管或卸载。
- 所有卸载路径只能删除所有权标记中记录且位于允许目录内的对象。
- Linuxbrew 不支持普通卸载。

Linuxbrew 是裸机上的 host-scoped 组件，固定前缀为
`/home/linuxbrew/.linuxbrew`。真实前缀只由非 root 的 `omd-brew`
服务账号写入；`omd-brew` 组成员通过 root-owned gateway 使用标准
`brew` 命令。任意 Brew 变更都必须经过
`/var/lib/oh-my-devpod/linuxbrew/locks/mutation.lock`，共享公式记录位于
`/var/lib/oh-my-devpod/linuxbrew/inventory/`。普通用户本地 marker
只用于严格校验旧版本迁移，不能作为共享状态的第二份真相。

已存在的 Linuxbrew 只有在前缀 owner、owner 的 legacy OMD marker 和
`brew --prefix` 完全一致时才能自动迁移；未标记、伪造、前缀不一致或
包含 symlink 的安装必须以 `unmanaged-prefix-conflict` 失败。

所有权状态默认位于：

```text
~/.local/state/oh-my-devpod/managed/
/var/lib/oh-my-devpod/linuxbrew/
```

## 镜像配置

bootstrap 保存安装来源：

```text
~/.config/oh-my-devpod/source
```

- `github` 对应 `upstream` profile。
- `gitee` 对应 `cn` profile。

`cn` profile 在执行模块前配置 USTC Homebrew 源、TUNA uv/pip index，
以及默认走 TUNA 的 Micromamba `conda-forge`/`defaults` channels。
对于已经安装且由 OMD marker 标记的 Linuxbrew、uv 和 Micromamba，
`modules/lib/source-config.sh` 还会同步维护原生配置：

```text
${HOMEBREW_PREFIX}/etc/homebrew/brew.env
${XDG_CONFIG_HOME:-$HOME/.config}/uv/uv.toml
${XDG_CONFIG_HOME:-$HOME/.config}/pip/pip.conf
$HOME/.mambarc
```

这些文件只有在不存在或内容仍与 OMD 生成模板完全一致时才允许修改。
用户文件或用户修改过的 OMD 文件必须触发拒绝与事务回滚。切回 upstream
或卸载对应组件时，只删除仍与 OMD 模板匹配的文件。vendored 二进制不需要
访问其原始 GitHub release。

受管 Zsh 加载 Mamba shell hook，但不设置 `MAMBA_ROOT_PREFIX`。root prefix
由实际安装的 Mamba/Micromamba 决定；Homebrew formula 使用其当前版本的
Cellar prefix，代码不得硬编码具体版本目录。

`omd --update` 必须先完成 release 下载、SHA256 校验和 bundle 校验，再由
候选 release 自带的 bootstrap 在隔离子 shell 中激活新版本。当前 release
不得使用自己的安装函数替换候选版本，避免旧安装器缺陷阻断后续修复。
来源配置使用临时文件和原子重命名；后续失败时恢复原配置、原生工具配置和
受管 Homebrew/core remote。显式来源切换在版本相同时仍需执行。

官方 Gitee CLI 没有 Homebrew formula。它由
`build/install-gitee-cli.sh` 从 Gitee release API 获取最新 Linux
amd64/arm64 资产，强制校验 release 内的 SHA256，验证二进制版本后在
`~/.local/bin` 原子替换。该组件只能管理二进制和所有权标记，必须保留
`~/.config/gitee`、自定义 `GITEE_CONFIG_DIR`、Agent Skills 与认证状态。

npm 安装通过 `OHMYDEVPOD_SOURCE=github|gitee npm install -g
oh-my-devpod` 选择 profile。npm launcher 将安装渠道和来源传递给 Rust
runtime；npm 渠道不得执行内建 `omd --update`，必须提示使用
`npm update -g oh-my-devpod`，避免出现两个安装所有者。
`omd --source github|gitee` 独立切换组件来源；npm launcher 优先读取
用户配置目录中的 `npm-source`，因此切源不依赖 npm 重新执行
`postinstall`。source-only 路径不得查询或下载 `omd` release。

## Release bundle

release archive 必须包含：

```text
oh-my-devpod/
├── bin/omd
├── components.toml
├── install/
├── modules/
├── build/
├── config/
├── vendor/
├── VERSION
└── versions.env
```

GitHub 和 Gitee 必须发布相同 archive 与 checksum，不能分别构建。
npm 包必须从同一个 release archive 组装，不得重新构建另一份二进制或在
`postinstall` 阶段联网下载 release。

npm 首次发布和后续 trusted publishing 配置见
[`docs/npm-release.md`](./docs/npm-release.md)。

## 版本管理

`VERSION`、`crates/omd/Cargo.toml` 与 `npm/package.json`
必须保持完全一致。开发版本使用 SemVer prerelease 格式，例如
`0.12.0-dev.0`。

更新 vendored 工具：

1. 修改 `versions.env`。
2. 同步对应 `build/install-*.sh` 的 fallback。
3. 执行 `bash build/update-vendor-assets.sh`。
4. 检查 `vendor/manifest.lock.json` 和 `docs/vendor-assets.md`。

## Issue 与提交

- 实质改动使用 GitHub issue 跟踪。
- 提交使用 Conventional Commit。
- 实现提交包含 `Refs #<issue>`。
- 不直接把未验证的功能提交到 `main`。

## 验证

```bash
bash tests/run.sh
cargo fmt --all -- --check
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --list-components
cargo run -p omd -- --plan install lazyvim
git diff --check
```
