ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm && rm -rf /var/lib/apt/lists/*

COPY runtime/codexpod /opt/runtime/codexpod
RUN OPENPOD_PREFIX=/opt/codexpod OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CONFIG_HOME=/root/.codex \
      bash /opt/runtime/codexpod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.codex /opt/devpod-skel/.codex \
    && chmod -R a+rX /opt/devpod-skel
