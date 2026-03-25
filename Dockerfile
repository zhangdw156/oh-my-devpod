# 基于官方 OpenCode 镜像
FROM ghcr.io/anomalyco/opencode AS base

# --------------------------
# 1. 安装基础依赖 (Alpine 版)
# --------------------------
# 如果 OpenCode 基础镜像是 Debian/Ubuntu 系，请将下方 apk 替换为 apt-get
RUN apk add --no-cache \
    zsh \
    git \
    curl \
    fzf \
    exa \
    bat \
    tzdata

# --------------------------
# 2. 环境变量
# --------------------------
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh

# --------------------------
# 3. 安装 Antidote
# --------------------------
RUN git clone --depth=1 https://github.com/mattmc3/antidote.git /opt/antidote

# --------------------------
# 4. 复制配置文件
# --------------------------
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
COPY config/.zsh_plugins.txt /root/.zsh_plugins.txt

# --------------------------
# 5. 预下载插件 (构建时执行，加速启动)
# --------------------------
RUN echo 'source /opt/antidote/antidote.zsh' >> /root/.zshrc_temp && \
    echo 'antidote load /root/.zsh_plugins.txt' >> /root/.zshrc_temp && \
    zsh -c "source /root/.zshrc_temp" && \
    rm /root/.zshrc_temp

# --------------------------
# 6. 启动设置
# --------------------------
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
