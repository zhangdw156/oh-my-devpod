# 开发者文档

## 架构边界

oh-my-devpod 是 Ubuntu 24.04 开发生产力工具管理器。`omd` 负责交互、
依赖规划和模块编排；Shell 模块负责单个工具的状态探测与生命周期操作。

```text
components.toml            组件目录与依赖真源
install/bootstrap.sh       GitHub/Gitee release bootstrap
crates/omd/                Rust TUI、planner、runner
modules/core/              Linuxbrew、Zsh、uv
modules/tools/             独立生产力工具与配置
modules/lib/common.sh      所有权、安全路径和包管理公共逻辑
build/package-omd.sh       完整 runtime bundle 打包
build/install-*.sh         vendored 二进制/配置安装器
config/                    项目维护的配置 overlay
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

所有权状态默认位于：

```text
~/.local/state/oh-my-devpod/managed/
```

## 镜像配置

bootstrap 保存安装来源：

```text
~/.config/oh-my-devpod/source
```

- `github` 对应 `upstream` profile。
- `gitee` 对应 `cn` profile。

`cn` profile 在执行模块前配置 USTC Homebrew 源和 TUNA Python index。
vendored 二进制不需要访问其原始 GitHub release。

## Release bundle

release archive 必须包含：

```text
oh-my-devpod/
├── bin/omd
├── components.toml
├── modules/
├── build/
├── config/
├── vendor/
├── VERSION
└── versions.env
```

GitHub 和 Gitee 必须发布相同 archive 与 checksum，不能分别构建。

## 版本管理

`VERSION` 与 `crates/omd/Cargo.toml` 必须保持完全一致。开发版本使用
SemVer prerelease 格式，例如 `0.12.0-dev.0`。

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
