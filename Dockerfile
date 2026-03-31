FROM ubuntu:24.04 AS base

# ---------- 1. 安装基础依赖 ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    zsh \
    git \
    vim \
    curl \
    file \
    ripgrep \
    tzdata \
    ca-certificates \
    musl \
    && rm -rf /var/lib/apt/lists/*

# ---------- 2. 安装 opencode（Alpine musl 构建，需要连同依赖库一起拷贝）----------
COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > /etc/ld-musl-x86_64.path

# ---------- 3. 安装 btop（默认使用官方最新 release，可通过构建参数覆盖）----------
ARG TARGETARCH
ARG BTOP_VERSION=latest
COPY build/install-btop.sh /tmp/install-btop.sh
RUN bash /tmp/install-btop.sh && rm -f /tmp/install-btop.sh

# ---------- 4. 安装 Antidote（默认使用官方最新 release，可通过构建参数覆盖）----------
ARG ANTIDOTE_VERSION=latest
COPY build/install-antidote.sh /tmp/install-antidote.sh
RUN bash /tmp/install-antidote.sh && rm -f /tmp/install-antidote.sh

# ---------- 5. 安装 zellij（默认使用官方最新 release，可通过构建参数覆盖）----------
ARG ZELLIJ_VERSION=latest
COPY build/install-zellij.sh /tmp/install-zellij.sh
RUN bash /tmp/install-zellij.sh && rm -f /tmp/install-zellij.sh

# ---------- 6. 安装 Yazi（默认使用官方最新 release，可通过构建参数覆盖）----------
ARG YAZI_VERSION=latest
COPY build/install-yazi.sh /tmp/install-yazi.sh
RUN bash /tmp/install-yazi.sh && rm -f /tmp/install-yazi.sh

# ---------- 7. 安装 uv (Python 包管理器) ----------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------- 8. 环境变量 ----------
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh
ENV UV_LINK_MODE=copy
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# ---------- 9. 允许 git 操作挂载目录（容器 root 与宿主机 UID 不同）----------
RUN git config --global --add safe.directory '*'

# ---------- 10. 复制配置文件 ----------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY config/.zsh_plugins.txt /root/.zsh_plugins.txt

# ---------- 11. 预下载插件 (构建时执行，加速启动) ----------
RUN zsh -c "source /opt/antidote/antidote.zsh && antidote load /root/.zsh_plugins.txt" || true

# ---------- 12. 启动设置 ----------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
