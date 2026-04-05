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
    perl \
    ripgrep \
    tzdata \
    unzip \
    vim \
    zsh \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------- 2. 复制 vendored 构建资产 ----------
COPY vendor /opt/vendor

# ---------- 3. 预置 Claude skills ----------
RUN mkdir -p /root/.claude \
    && ln -sfn /opt/vendor/claude/skills /root/.claude/skills

# ---------- 4. 安装 Claude Code ----------
COPY build/install-claude-code.sh /tmp/install-claude-code.sh
RUN OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CLAUDE_INSTALL_HOME=/root bash /tmp/install-claude-code.sh \
    && rm -f /tmp/install-claude-code.sh

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

# ---------- 10. 安装 uv (Python 包管理器) ----------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ---------- 11. 预装 Python 开发工具 ----------
COPY build/install-python-dev-tools.sh /tmp/install-python-dev-tools.sh
RUN bash /tmp/install-python-dev-tools.sh && rm -f /tmp/install-python-dev-tools.sh

# ---------- 12. 安装默认 LazyVim 配置 ----------
COPY config/nvim /opt/openpod-config/nvim
COPY build/install-lazyvim.sh /tmp/install-lazyvim.sh
RUN OPENPOD_NVM_OVERLAY_DIR=/opt/openpod-config/nvim bash /tmp/install-lazyvim.sh && rm -f /tmp/install-lazyvim.sh

# ---------- 13. 环境变量 ----------
# btop / 终端 Unicode 依赖 UTF-8 locale；基础镜像默认为 POSIX
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV OPENPOD_CLAUDE_CODE_VERSION=2.1.92
ENV DISABLE_AUTOUPDATER=1
ENV OPENPOD_CLAUDE_REAL_BIN=/usr/local/bin/claude-real
ENV OPENPOD_LAZYVIM_STARTER_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99
ENV OPENPOD_LAZYVIM_SOURCE_DIR=/opt/vendor/nvim/lazyvim-starter
ENV OPENPOD_NEOVIM_DIR=/opt/neovim
ENV OPENPOD_NVM_OVERLAY_DIR=/opt/openpod-config/nvim
ENV OPENPOD_PYRIGHT_VERSION=1.1.408
ENV OPENPOD_RUFF_VERSION=0.15.9
ENV OPENPOD_UV_TOOL_DIR=/opt/uv-tools
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh
ENV UV_LINK_MODE=copy
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then ln -sf "$(command -v fdfind)" /usr/local/bin/fd; fi

# ---------- 14. 允许 git 操作挂载目录（容器 root 与宿主机 UID 不同）----------
RUN git config --global --add safe.directory '*'

# ---------- 15. 复制配置文件 ----------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY bin/claude /usr/local/bin/claude
COPY bin/claudepod-shell /usr/local/bin/claudepod-shell
COPY bin/openpod-shell /usr/local/bin/openpod-shell
RUN chmod 0755 /usr/local/bin/claude /usr/local/bin/claudepod-shell /usr/local/bin/openpod-shell

# ---------- 16. 启动设置 ----------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
