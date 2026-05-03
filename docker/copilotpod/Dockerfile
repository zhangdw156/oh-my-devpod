ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/copilotpod /opt/runtime/copilotpod
RUN OHMYDEVPOD_REPO_ROOT=/opt OHMYDEVPOD_PREFIX=/opt/copilotpod OHMYDEVPOD_BIN_DIR=/usr/local/bin OHMYDEVPOD_CONFIG_HOME=/root/.copilot \
      OHMYDEVPOD_COPILOT_VERSION=1.0.24 \
      bash /opt/runtime/copilotpod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.copilot /opt/devpod-skel/.copilot \
    && chmod -R a+rX /opt/devpod-skel

ENV OHMYDEVPOD_COPILOT_VERSION=1.0.24
ENV OHMYDEVPOD_COPILOT_REAL_BIN=/usr/local/bin/copilot-real
