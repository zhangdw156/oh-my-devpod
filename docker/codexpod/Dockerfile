ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/codexpod /opt/runtime/codexpod
RUN OHMYDEVPOD_REPO_ROOT=/opt OHMYDEVPOD_PREFIX=/opt/codexpod OHMYDEVPOD_BIN_DIR=/usr/local/bin OHMYDEVPOD_CONFIG_HOME=/root/.codex \
      OHMYDEVPOD_CODEX_VERSION=0.118.0 \
      bash /opt/runtime/codexpod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.codex /opt/devpod-skel/.codex \
    && chmod -R a+rX /opt/devpod-skel

ENV OHMYDEVPOD_CODEX_VERSION=0.118.0
ENV OHMYDEVPOD_CODEX_REAL_BIN=/usr/local/bin/codex-real
