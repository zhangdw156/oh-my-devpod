ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY build/install-claude-code.sh /opt/build/install-claude-code.sh
RUN OHMYDEVPOD_BIN_DIR=/usr/local/bin OHMYDEVPOD_CLAUDE_INSTALL_HOME=/root bash /opt/build/install-claude-code.sh

COPY runtime/claudepod /opt/runtime/claudepod
RUN mkdir -p /root/.claude \
    && ln -sfn /opt/runtime/claudepod/skills /root/.claude/skills \
    && cp /opt/runtime/claudepod/bin/claude /usr/local/bin/claude \
    && cp /opt/runtime/claudepod/bin/claudepod-shell /usr/local/bin/claudepod-shell \
    && cp /opt/runtime/claudepod/bin/claudepod-upgrade /usr/local/bin/claudepod-upgrade \
    && chmod 0755 /usr/local/bin/claude /usr/local/bin/claudepod-shell /usr/local/bin/claudepod-upgrade

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.claude /opt/devpod-skel/.claude \
    && cp -a /root/.claude.json /opt/devpod-skel/.claude.json \
    && mkdir -p /opt/devpod-skel/.local \
    && cp -a /root/.local/share /opt/devpod-skel/.local/share \
    && if [ -d /root/.local/bin ]; then cp -a /root/.local/bin /opt/devpod-skel/.local/bin; fi \
    && chmod -R a+rX /opt/devpod-skel
ENV DISABLE_AUTOUPDATER=1
ENV OHMYDEVPOD_CLAUDE_CODE_VERSION=2.1.92
ENV OHMYDEVPOD_CLAUDE_REAL_BIN=/usr/local/bin/claude-real
ENV OHMYDEVPOD_REPO_ROOT=/opt
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
