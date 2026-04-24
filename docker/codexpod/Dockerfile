ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/codexpod /opt/runtime/codexpod
RUN OPENPOD_REPO_ROOT=/opt OPENPOD_PREFIX=/opt/codexpod OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CONFIG_HOME=/root/.codex \
      bash /opt/runtime/codexpod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.codex /opt/devpod-skel/.codex \
    && chmod -R a+rX /opt/devpod-skel
