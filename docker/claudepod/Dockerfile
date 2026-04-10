ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY build/install-claude-code.sh /tmp/install-claude-code.sh
RUN OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CLAUDE_INSTALL_HOME=/root bash /tmp/install-claude-code.sh \
    && rm -f /tmp/install-claude-code.sh

COPY runtime/claudepod /opt/runtime/claudepod
RUN mkdir -p /root/.claude \
    && ln -sfn /opt/runtime/claudepod/skills /root/.claude/skills \
    && cp /opt/runtime/claudepod/bin/claude /usr/local/bin/claude \
    && cp /opt/runtime/claudepod/bin/claudepod-shell /usr/local/bin/claudepod-shell \
    && chmod 0755 /usr/local/bin/claude /usr/local/bin/claudepod-shell

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.claude /opt/devpod-skel/.claude \
    && cp -a /root/.claude.json /opt/devpod-skel/.claude.json \
    && mkdir -p /opt/devpod-skel/.local \
    && cp -a /root/.local/share /opt/devpod-skel/.local/share \
    && cp -a /root/.local/bin /opt/devpod-skel/.local/bin \
    && chmod -R a+rX /opt/devpod-skel
ENV DISABLE_AUTOUPDATER=1
ENV OPENPOD_CLAUDE_CODE_VERSION=2.1.92
ENV OPENPOD_CLAUDE_REAL_BIN=/usr/local/bin/claude-real
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
