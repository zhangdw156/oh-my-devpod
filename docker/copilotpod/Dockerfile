ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/copilotpod /opt/runtime/copilotpod
RUN OPENPOD_REPO_ROOT=/opt OPENPOD_PREFIX=/opt/copilotpod OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CONFIG_HOME=/root/.copilot \
      bash /opt/runtime/copilotpod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.copilot /opt/devpod-skel/.copilot \
    && chmod -R a+rX /opt/devpod-skel

ENV OPENPOD_COPILOT_VERSION=1.0.24
ENV OPENPOD_COPILOT_REAL_BIN=/usr/local/bin/copilot-real
