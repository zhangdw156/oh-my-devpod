# 开发者文档

## 项目结构（完整）

```
oh-my-openpod/
├── Dockerfile
├── docker-compose.yml          # 版本号在 image 字段中维护
├── .env.example
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── README.md                   # 用户文档
├── DEVELOPMENT.md              # 开发者文档（本文件）
├── build/
│   ├── install-antidote.sh
│   ├── install-btop.sh
│   ├── install-lazyvim.sh
│   ├── install-neovim.sh
│   ├── update-vendor-assets.sh
│   ├── install-yazi.sh
│   └── install-zellij.sh
├── docs/
│   └── vendor-assets.md
├── tests/
│   ├── run.sh
│   ├── test-install-lazyvim.sh
│   ├── test-install-neovim.sh
│   └── test-neovim-lazyvim-wiring.sh
├── config/
│   ├── .zshrc
│   ├── .p10k.zsh
│   ├── .zsh_plugins.txt
│   └── opencode.json          # 镜像内置的 OpenCode 全局默认配置
└── vendor/
    ├── manifest.lock.json
    ├── nvim/
    │   └── lazyvim-starter/
    ├── opencode/
    │   ├── packages/
    │   │   └── superpowers/
    │   └── skills/
    ├── releases/
    └── zsh/
```

## 版本管理

版本号唯一维护在 `docker-compose.yml` 的 `image` 字段中：

```yaml
image: oh-my-openpod:x.y.z.dev0  # 开发中
image: oh-my-openpod:x.y.z       # 正式发布
```

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
- workflow 登录 GHCR 时优先使用仓库 secret `GHCR_TOKEN`，回退到 `GITHUB_TOKEN`
- `GHCR_TOKEN` 需要具备至少 `write:packages`；这是保证个人账号下 GHCR 包稳定可写的一次性配置
- 发布镜像显式关闭 `provenance`，避免 GHCR 页面出现额外的 `unknown/unknown` attestation 条目

## 依赖安装约定

- `build/` 目录存放镜像构建期使用的安装脚本，例如 `install-antidote.sh`、`install-btop.sh`、`install-neovim.sh`、`install-lazyvim.sh`、`install-yazi.sh` 和 `install-zellij.sh`
- 这些安装脚本同时也是 bootstrap 模式的基础构件；新增脚本时优先保持可通过环境变量改写安装前缀与目标路径
- `build/update-vendor-assets.sh` 用于刷新仓库内维护的 release 包、LazyVim starter 快照、Zsh 插件快照和 OpenCode 插件包快照
- `config/` 目录存放要复制进镜像的配置文件，包括 shell 配置和内置的 `opencode.json`
- `vendor/releases/` 存放构建脚本使用的固定 release 包，`vendor/nvim/` 存放默认 Neovim 配置快照，`vendor/zsh/` 存放默认 shell 使用的插件源码快照
- `vendor/opencode/packages/` 存放需要保留原始包结构的 OpenCode 插件包快照
- `vendor/opencode/skills/` 预留给仓库直接维护的 OpenCode 全局 skills
- `tests/` 目录存放仓库维护的 shell 级回归测试；优先覆盖安装脚本行为和关键接线关系
- `vendor/manifest.lock.json` 和 `docs/vendor-assets.md` 一起维护本地资产的来源、版本、校验和与更新方式
- 默认本地 `docker build` 不再依赖 GitHub release、Zsh 插件仓库或 OpenCode 插件仓库的运行时拉取，但仍需要访问基础镜像来源，例如 Docker Hub 和 GHCR

### Neovim / LazyVim 资产约定

- `neovim` 二进制通过官方 release tar 包维护在 `vendor/releases/neovim/`
- `LazyVim/starter` 通过 pinned source snapshot 维护在 `vendor/nvim/lazyvim-starter/`
- 不要在 Dockerfile 或 bootstrap 脚本里直接在线 `git clone LazyVim/starter`
- `build/install-lazyvim.sh` 负责把 vendored starter 安装到标准 `nvim` 配置目录，并在首次接管非 openpod 管理目录时自动备份 `config/data/state/cache`
- `vendor/nvim/lazyvim-starter/.openpod-source-commit` 用于记录 pinned starter commit，便于安装元数据与后续升级

### OpenCode 资产约定

- `superpowers` 以完整包快照的形式维护在 `vendor/opencode/packages/superpowers/`
- 不要只抽取 `.opencode/plugins/superpowers.js` 或只复制 `skills/`，因为上游插件会基于自身入口文件相对路径解析 `../../skills`
- 镜像构建时会在 `/root/.config/opencode/plugins/superpowers.js` 创建指向 vendored 包入口的软链接
- 镜像构建时还会在 `/root/.config/opencode/skills` 创建指向 `/opt/vendor/opencode/skills` 的软链接，避免项目级 `opencode.json` 覆盖掉仓库维护的全局 skills
- 镜像还会把 `config/opencode.json` 复制到 `/root/.config/opencode/config.json`，作为 OpenCode 的全局默认配置
- `config/opencode.json` 只保留镜像级 provider 默认值；不要在其中手动添加 `superpowers/skills`，因为插件会在运行时注册它自己的 bundled skills
- `docker-compose.yml` 不再从宿主机挂载全局 OpenCode 配置；项目级自定义应放在挂载到 `/workspace` 的项目根目录 `opencode.json`

## 发布流程

```bash
# 1. 从 main 新建发布分支
git checkout main
git pull --ff-only origin main
git checkout -b release/x.y.z

# 2. 修改 docker-compose.yml 中 image 的 tag（去掉开发后缀）
#    image: oh-my-openpod:x.y.z
git add docker-compose.yml
git commit -m "release: cut x.y.z"
git push -u origin release/x.y.z

# 3. 提 PR 合并到 main
#    合并后，GitHub Actions 会自动构建并发布：
#    ghcr.io/zhangdw156/oh-my-openpod:x.y.z
#    ghcr.io/zhangdw156/oh-my-openpod:latest

# 4. 发布成功后，给 release commit 打 tag 并创建 GitHub Release
git checkout main
git pull --ff-only origin main
git tag vx.y.z
git push origin vx.y.z

# 5. 开始下一个版本的开发
git checkout -b chore/bump-version-to-next-dev
#    image: oh-my-openpod:<next-version>.dev0
git add docker-compose.yml
git commit -m "chore: bump version to <next-version>.dev0"
git push -u origin chore/bump-version-to-next-dev

# 6. 提 PR 合并到 main
#    这次 workflow 会自动跳过镜像发布，因为版本使用 .devN 开发后缀
```
