FROM ghcr.io/anomalyco/opencode AS base

# ---------- 1. 安装基础依赖 (Alpine) ----------
RUN apk add --no-cache \
    zsh \
    git \
    curl \
    fzf \
    exa \
    bat \
    tzdata

# ---------- 2. 安装 uv (Python 包管理器) ----------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------- 3. 环境变量 ----------
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh

# ---------- 4. 安装 Antidote (zsh 插件管理器，版本由 git submodule 管理) ----------
COPY vendor/antidote /opt/antidote

# ---------- 5. 复制配置文件 ----------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY config/.zsh_plugins.txt /root/.zsh_plugins.txt

# ---------- 6. 预下载插件 (构建时执行，加速启动) ----------
RUN zsh -c "source /opt/antidote/antidote.zsh && antidote load /root/.zsh_plugins.txt" || true

# ---------- 7. 启动设置 ----------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
