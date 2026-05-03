# 开发者文档

## 项目结构（完整）

```text
oh-my-devpod/
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
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── README.md                   # 用户文档
├── DEVELOPMENT.md              # 开发者文档（本文件）
├── build/
│   ├── install-antidote.sh
│   ├── install-btop.sh
│   ├── install-claude-code.sh
│   ├── install-lazyvim.sh
│   ├── install-neovim.sh
│   ├── install-python-dev-tools.sh
│   ├── update-vendor-assets.sh
│   ├── install-yazi.sh
│   └── install-zellij.sh
├── docs/
│   └── vendor-assets.md
├── runtime/
│   ├── openpod/
│   │   ├── bin/
│   │   ├── config/
│   │   │   └── opencode.json   # openpod flavor 的 OpenCode 默认配置
│   │   └── vendor/
│   │       └── opencode/       # openpod flavor 独占的 OpenCode vendored 资产
│   ├── claudepod/
│   ├── codexpod/
│   ├── copilotpod/
│   └── geminipod/
├── tests/
│   ├── run.sh
│   ├── test-compose-flavors.sh
│   ├── test-install-lazyvim.sh
│   ├── test-install-neovim.sh
│   ├── test-neovim-lazyvim-wiring.sh
│   └── test-openpod-runtime-assets.sh
├── config/
│   ├── nvim/
│   │   └── lua/plugins/python.lua
│   ├── .zshrc
│   ├── .p10k.zsh
│   └── .zsh_plugins.txt
└── vendor/
    ├── manifest.lock.json
    ├── nvim/
    │   └── lazyvim-starter/
    ├── releases/
    └── zsh/
```

## 版本管理

仓库根目录 `VERSION` 文件是六个镜像唯一的版本真源，格式为 `x.y.z.devN`（开发）或 `x.y.z`（正式发布）。

仓库根目录 `versions.env` 是所有工具版本的唯一真源。构建脚本（`build/update-vendor-assets.sh`）直接 source 此文件；安装脚本（`build/install-*.sh`）通过环境变量接收版本并保留回退默认值；Dockerfile 通过 ARG 声明版本（默认值与 `versions.env` 保持同步）。更新工具版本时，先改 `versions.env`，然后同步 Dockerfile ARG 默认值和 install 脚本回退默认值。`tests/test-versions-env.sh` 会验证这些值的一致性。

`docker/<flavor>/docker-compose.yaml` 默认从 `ghcr.io/zhangdw156/{flavor}:${IMAGE_VERSION:-latest}` 拉取官方镜像。如需本地构建，可取消注释 compose 文件中的 `build:` 段。`VERSION` 文件是版本真源，compose 不会自动读取它。

| 版本格式 | 含义 |
|----------|------|
| `x.y.z.devN` | 开发中，尚未发布 |
| `x.y.z` | 已发布的正式版本 |

## Issue 约定

- 新 issue 默认通过 GitHub Web UI 的 issue form 创建，统一走 `.github/ISSUE_TEMPLATE/`
- 史诗任务使用 `Epic / 史诗任务` 模板，标题前缀保持为 `[Epic] `
- 功能建议使用 `Feature Request / 功能建议` 模板，标题前缀保持为 `[Feature] `
- 缺陷反馈使用 `Bug Report / Bug 反馈` 模板，标题前缀保持为 `[Bug] `
- `gh issue create` 不会自动套用 issue form；除非手动补齐相同标题和表单内容，否则不要直接用 CLI 裸建 issue

## 发布实现约定

- 正式版镜像由 `.github/workflows/publish-ghcr.yml` 在 `main` 分支自动发布
- workflow 登录 GHCR 时使用内置的 `GITHUB_TOKEN`（job 已声明 `packages: write` 权限）
- 发布镜像显式关闭 `provenance`，避免 GHCR 页面出现额外的 `unknown/unknown` attestation 条目
- 发布产物包含共享 `devpod` 基座以及 `openpod`、`claudepod`、`codexpod`、`copilotpod`、`geminipod`

## 依赖安装约定

- Docker 构建路径（`Dockerfile.devpod`）使用 apt 安装系统包，并从 `vendor/releases/` 解压 vendored 二进制；此路径完全离线（除 harness 安装端点外）
- `build/` 目录存放镜像构建期使用的安装脚本，例如 `install-antidote.sh`、`install-btop.sh`、`install-claude-code.sh`、`install-neovim.sh`、`install-python-dev-tools.sh`、`install-lazyvim.sh`、`install-yazi.sh` 和 `install-zellij.sh`
- 这些安装脚本仅在 Docker 构建路径中使用
- `build/update-vendor-assets.sh` 用于刷新共享 release 包、LazyVim starter 快照、Zsh 插件快照，并同步 flavor 目录下复用的 skills
- `config/` 目录只存放共享配置，例如 shell 配置和 `nvim` overlay
- `runtime/` 目录按 flavor 拆分 harness 相关安装脚本、launcher、config、skills 和 flavor 自己拥有的 vendored 资产
- `vendor/releases/` 存放构建脚本使用的固定 release 包，`vendor/nvim/` 存放默认 Neovim 配置快照，`vendor/zsh/` 存放默认 shell 使用的插件源码快照
- `config/nvim/` 存放仓库直接维护的 LazyVim overlay；用于在不修改 vendored starter 快照的前提下追加 openpod 默认行为
- `runtime/openpod/vendor/opencode/packages/` 存放需要保留原始包结构的 OpenCode 插件包快照
- `runtime/openpod/vendor/opencode/skills/` 预留给仓库直接维护的 OpenCode 全局 skills
- `runtime/claudepod/skills/`、`runtime/codexpod/skills/`、`runtime/copilotpod/skills/`、`runtime/geminipod/skills/` 可承载从 OpenCode vendored superpowers 同步出的 flavor-owned skills
- `tests/` 目录存放仓库维护的 shell 级回归测试；优先覆盖 flavor 编排、安装脚本行为和关键接线关系
- `vendor/manifest.lock.json` 和 `docs/vendor-assets.md` 一起维护本地资产的来源、版本、校验和与更新方式
- `docs/environment-variables.md` 提供所有 `OHMYDEVPOD_*` 环境变量的完整参考文档
- 默认本地 `docker build` 不再依赖 GitHub release、Zsh 插件仓库或 OpenCode 插件仓库的运行时拉取，但仍需要访问基础镜像来源，例如 Docker Hub 和 GHCR，以及未 vendored 的 harness 安装端点

### Neovim / LazyVim 资产约定

- `neovim` 二进制通过官方 release tar 包维护在 `vendor/releases/neovim/`
- `LazyVim/starter` 通过 pinned source snapshot 维护在 `vendor/nvim/lazyvim-starter/`
- `pyright[nodejs]` 与 `ruff` 通过 `build/install-python-dev-tools.sh` 以 pinned PyPI 版本安装，不通过 Mason 或 npm 单独管理
- 不要在 Dockerfile 里直接在线 `git clone LazyVim/starter`
- `build/install-lazyvim.sh` 负责把 vendored starter 安装到标准 `nvim` 配置目录，并在首次接管非 openpod 管理目录时自动备份 `config/data/state/cache`
- `config/nvim/` 里的 overlay 会在 starter 安装完成后覆盖到目标配置目录，用于启用 openpod 默认的 Python extra
- `vendor/nvim/lazyvim-starter/.openpod-source-commit` 用于记录 pinned starter commit，便于安装元数据与后续升级

### OpenCode 资产约定

- `superpowers` 以完整包快照的形式维护在 `runtime/openpod/vendor/opencode/packages/superpowers/`
- 不要只抽取 `.opencode/plugins/superpowers.js` 或只复制 `skills/`，因为上游插件会基于自身入口文件相对路径解析 `../../skills`
- 镜像构建时会在 `/root/.config/opencode/plugins/superpowers.js` 创建指向 vendored 包入口的软链接
- 镜像构建时还会把 skills 以真实目录（`cp -a`）拷贝到对应的配置目录，以便用户在运行时添加自己的 skills
- 镜像还会把 `runtime/openpod/config/opencode.json` 复制到 `/root/.config/opencode/config.json`，作为 OpenCode 的全局默认配置
- `runtime/openpod/config/opencode.json` 只保留最小镜像级默认配置；不要在其中手动添加 `superpowers/skills`，因为插件会在运行时注册它自己的 bundled skills
- `build/update-vendor-assets.sh` 会刷新 `runtime/openpod/vendor/opencode/packages/superpowers/`，但不会破坏 `runtime/openpod/vendor/opencode/skills/`
- pod-local compose 文件不从宿主机挂载全局 OpenCode 配置；项目级自定义应放在挂载到 `/workspace` 的项目根目录 `opencode.json`

### 其他 harness 约定

- `claudepod` 使用原生二进制安装（`build/install-claude-code.sh`），不通过 npm；安装目录为 `~/.local/share/claude/versions/`，与其他 npm-based flavor 不同
- `openpod` 通过 `COPY --from=ghcr.io/anomalyco/opencode` 直接获取二进制，不使用 CLI wrapper 脚本（其他 flavor 均通过 `OHMYDEVPOD_*_REAL_BIN` 间接调用）
- `codexpod` 使用 `@openai/codex`
- `copilotpod` 使用 `@github/copilot`
- `geminipod` 使用 `@google/gemini-cli`
- `codexpod`、`copilotpod`、`geminipod` 均要求 `Node.js >=20`
- `copilotpod` 的用户级配置目录为 `~/.copilot/`，可通过 `GH_TOKEN` / `GITHUB_TOKEN` 提供非交互认证
- `geminipod` 的用户级配置目录为 `~/.gemini/`，headless 场景优先使用 `GEMINI_API_KEY` 或 Vertex AI 相关环境变量

### Multi-Flavor 约定

- 共享基础层只放在 `Dockerfile.devpod` 和 `build/` 中
- flavor 差异只能出现在 `runtime/<flavor>/` 和对应的 `docker/<flavor>/Dockerfile` 中
- `docker/<flavor>/docker-compose.yaml` 只为对应 pod 提供本地入口，默认从 GHCR 拉取官方镜像
- flavor Dockerfile 通过 `additional_contexts` 复用 `devpod` 基座
- 新增 harness 时，先创建新的 `runtime/<flavor>/`，不要把逻辑直接写进共享基座

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

# 3. 创建 PR 并 squash 合并（自动删除分支）
gh pr create --title "release: cut x.y.z" --body ""
gh pr merge --squash --delete-branch
#    合并后，GitHub Actions 会自动构建并发布：
#    ghcr.io/zhangdw156/devpod:x.y.z
#    ghcr.io/zhangdw156/openpod:x.y.z
#    ghcr.io/zhangdw156/claudepod:x.y.z
#    ghcr.io/zhangdw156/codexpod:x.y.z
#    ghcr.io/zhangdw156/copilotpod:x.y.z
#    ghcr.io/zhangdw156/geminipod:x.y.z
#    （每个镜像同时推送 x.y.z 和 latest 两个 tag）

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

# 6. 创建 PR 并 squash 合并（自动删除分支）
gh pr create --title "chore: bump version to <next-version>.dev0" --body ""
gh pr merge --squash --delete-branch
#    这次 workflow 会自动跳过镜像发布，因为版本使用 .devN 开发后缀
```
