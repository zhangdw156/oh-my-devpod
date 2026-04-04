FROM ubuntu:24.04 AS base

# ---------- 1. 安装基础依赖 ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    curl \
    fd-find \
    file \
    gcc \
    git \
    make \
    ripgrep \
    tzdata \
    unzip \
    vim \
    zsh \
    ca-certificates \
    musl \
    && rm -rf /var/lib/apt/lists/*

# ---------- 2. 复制 vendored 构建资产 ----------
COPY vendor /opt/vendor

# ---------- 3. 预置 OpenCode vendored plugin 入口与全局 skills ----------
RUN mkdir -p /root/.config/opencode/plugins \
    && ln -sf /opt/vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js /root/.config/opencode/plugins/superpowers.js \
    && ln -sfn /opt/vendor/opencode/skills /root/.config/opencode/skills

# ---------- 4. 安装 opencode（Alpine musl 构建，需要连同依赖库一起拷贝）----------
COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > /etc/ld-musl-x86_64.path

# ---------- 5. 安装 btop（使用 vendored release 包）----------
ARG TARGETARCH
COPY build/install-btop.sh /tmp/install-btop.sh
RUN bash /tmp/install-btop.sh && rm -f /tmp/install-btop.sh

# ---------- 6. 安装 Antidote（使用 vendored release 包）----------
COPY build/install-antidote.sh /tmp/install-antidote.sh
RUN bash /tmp/install-antidote.sh && rm -f /tmp/install-antidote.sh

# ---------- 7. 安装 zellij（使用 vendored release 包）----------
COPY build/install-zellij.sh /tmp/install-zellij.sh
RUN bash /tmp/install-zellij.sh && rm -f /tmp/install-zellij.sh

# ---------- 8. 安装 Yazi（使用 vendored release 包）----------
COPY build/install-yazi.sh /tmp/install-yazi.sh
RUN bash /tmp/install-yazi.sh && rm -f /tmp/install-yazi.sh

# ---------- 9. 安装 Neovim（使用 vendored release 包）----------
COPY build/install-neovim.sh /tmp/install-neovim.sh
RUN bash /tmp/install-neovim.sh && rm -f /tmp/install-neovim.sh

# ---------- 10. 安装默认 LazyVim 配置 ----------
COPY build/install-lazyvim.sh /tmp/install-lazyvim.sh
RUN bash /tmp/install-lazyvim.sh && rm -f /tmp/install-lazyvim.sh

# ---------- 11. 安装 uv (Python 包管理器) ----------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------- 12. 环境变量 ----------
# btop / 终端 Unicode 依赖 UTF-8 locale；基础镜像默认为 POSIX
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV OPENPOD_LAZYVIM_STARTER_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99
ENV OPENPOD_LAZYVIM_SOURCE_DIR=/opt/vendor/nvim/lazyvim-starter
ENV OPENPOD_NEOVIM_DIR=/opt/neovim
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh
ENV UV_LINK_MODE=copy
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then ln -sf "$(command -v fdfind)" /usr/local/bin/fd; fi

# ---------- 13. 允许 git 操作挂载目录（容器 root 与宿主机 UID 不同）----------
RUN git config --global --add safe.directory '*'

# ---------- 14. 复制配置文件 ----------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY config/opencode.json /root/.config/opencode/config.json

# ---------- 15. 启动设置 ----------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
