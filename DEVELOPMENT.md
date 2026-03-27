# 开发者文档

## 项目结构（完整）

```
oh-my-openpod/
├── Dockerfile
├── docker-compose.yml          # 版本号在 image 字段中维护
├── .env.example
├── .gitmodules
├── opencode.json.example
├── README.md                   # 用户文档
├── DEVELOPMENT.md              # 开发者文档（本文件）
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
image: oh-my-openpod:0.1.0-dev   # 开发中
image: oh-my-openpod:0.1.0       # 正式发布
```

| 版本格式 | 含义 |
|----------|------|
| `x.y.z-dev` | 开发中，尚未发布 |
| `x.y.z` | 已发布的正式版本 |

## 发布流程

```bash
# 1. 修改 docker-compose.yml 中 image 的 tag（去掉 -dev）
#    image: oh-my-openpod:0.1.0
git add docker-compose.yml
git commit -m "chore: release v0.1.0"
git push origin main

# 2. 推送到 main 后，GitHub Actions 会自动构建并发布：
#    ghcr.io/zhangdw156/oh-my-openpod:0.1.0
#    ghcr.io/zhangdw156/oh-my-openpod:latest

# 3. 如需保留源码版本标签，可额外打 git tag
git tag v0.1.0
git push origin v0.1.0

# 4. 开始下一个版本的开发
#    image: oh-my-openpod:0.2.0-dev
git add docker-compose.yml
git commit -m "chore: begin development of v0.2.0"
git push origin main
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
