# 开发者文档

## 项目结构（完整）

```
oh-my-openpod/
├── Dockerfile
├── docker-compose.yml          # 版本号在 image 字段中维护
├── .env.example
├── .gitmodules
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── opencode.json.example
├── README.md                   # 用户文档
├── DEVELOPMENT.md              # 开发者文档（本文件）
├── build/
│   └── install-zellij.sh
├── config/
│   ├── .zshrc
│   ├── .p10k.zsh
│   └── .zsh_plugins.txt
└── vendor/                     # 第三方依赖（git submodule）
    └── antidote/               # Zsh 插件管理器，固定到 v2.0.2
```

## 版本管理

版本号唯一维护在 `docker-compose.yml` 的 `image` 字段中：

```yaml
image: oh-my-openpod:0.3.0-dev   # 开发中
image: oh-my-openpod:0.2.0       # 正式发布
```

| 版本格式 | 含义 |
|----------|------|
| `x.y.z-dev` | 开发中，尚未发布 |
| `x.y.z` | 已发布的正式版本 |

## Issue 约定

- 新 issue 默认通过 GitHub Web UI 的 issue form 创建，统一走 `.github/ISSUE_TEMPLATE/`
- 功能建议使用 `Feature Request / 功能建议` 模板，标题前缀保持为 `[Feature] `
- 缺陷反馈使用 `Bug Report / Bug 反馈` 模板，标题前缀保持为 `[Bug] `
- `gh issue create` 不会自动套用 issue form；除非手动补齐相同标题和表单内容，否则不要直接用 CLI 裸建 issue

## 发布实现约定

- 正式版镜像由 `.github/workflows/publish-ghcr.yml` 在 `main` 分支自动发布
- workflow 登录 GHCR 时优先使用仓库 secret `GHCR_TOKEN`，回退到 `GITHUB_TOKEN`
- `GHCR_TOKEN` 需要具备至少 `write:packages`；这是保证个人账号下 GHCR 包稳定可写的一次性配置
- 发布镜像显式关闭 `provenance`，避免 GHCR 页面出现额外的 `unknown/unknown` attestation 条目

## 发布流程

```bash
# 1. 从 main 新建发布分支
git checkout main
git pull --ff-only origin main
git checkout -b release/0.2.0

# 2. 修改 docker-compose.yml 中 image 的 tag（去掉 -dev）
#    image: oh-my-openpod:0.2.0
git add docker-compose.yml
git commit -m "release: cut 0.2.0"
git push -u origin release/0.2.0

# 3. 提 PR 合并到 main
#    合并后，GitHub Actions 会自动构建并发布：
#    ghcr.io/zhangdw156/oh-my-openpod:0.2.0
#    ghcr.io/zhangdw156/oh-my-openpod:latest

# 4. 发布成功后，给 release commit 打 tag 并创建 GitHub Release
git checkout main
git pull --ff-only origin main
git tag v0.2.0
git push origin v0.2.0

# 5. 开始下一个版本的开发
git checkout -b chore/bump-version-to-0.3.0-dev
#    image: oh-my-openpod:0.3.0-dev
git add docker-compose.yml
git commit -m "chore: bump version to 0.3.0-dev"
git push -u origin chore/bump-version-to-0.3.0-dev

# 6. 提 PR 合并到 main
#    这次 workflow 会自动跳过镜像发布，因为 tag 以 -dev 结尾
```

## 管理 Submodule

所有第三方依赖统一放在 `vendor/` 目录下，通过 git submodule 管理版本。

### 升级 Antidote

```bash
cd vendor/antidote
git fetch --tags
git checkout <new-tag>   # 例如 v2.1.0
cd ../..

# 更新 .gitmodules 中的 branch 字段以保持一致
# [submodule "vendor/antidote"]
#     branch = <new-tag>

git add vendor/antidote .gitmodules
git commit -m "chore: bump antidote to <new-tag>"
```

### 添加新的 Submodule

```bash
git submodule add <repo-url> vendor/<name>
git commit -m "chore: add <name> as submodule"
```
