FROM ubuntu:24.04 AS base

# ---------- 1. 安装基础依赖 ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh \
    git \
    curl \
    fzf \
    bat \
    eza \
    tzdata \
    libsndfile1 \
    ca-certificates \
    musl \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 下 bat 的二进制名为 batcat，建立软链保持用法一致
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat

# ---------- 2. 安装 opencode（Alpine musl 构建，需要连同依赖库一起拷贝）----------
COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > /etc/ld-musl-x86_64.path

# ---------- 3. 安装 uv (Python 包管理器) ----------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------- 4. 环境变量 ----------
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh
ENV UV_LINK_MODE=copy
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# ---------- 5. 允许 git 操作挂载目录（容器 root 与宿主机 UID 不同）----------
RUN git config --global --add safe.directory '*'

# ---------- 6. 安装 Antidote (zsh 插件管理器，版本由 git submodule 管理) ----------
COPY vendor/antidote /opt/antidote

# ---------- 7. 复制配置文件 ----------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY config/.zsh_plugins.txt /root/.zsh_plugins.txt

# ---------- 8. 预下载插件 (构建时执行，加速启动) ----------
RUN zsh -c "source /opt/antidote/antidote.zsh && antidote load /root/.zsh_plugins.txt" || true

# ---------- 9. 启动设置 ----------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
