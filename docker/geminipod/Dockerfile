ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/geminipod /opt/runtime/geminipod
RUN OHMYDEVPOD_REPO_ROOT=/opt OHMYDEVPOD_PREFIX=/opt/geminipod OHMYDEVPOD_BIN_DIR=/usr/local/bin OHMYDEVPOD_CONFIG_HOME=/root/.gemini \
      OHMYDEVPOD_GEMINI_VERSION=0.37.1 \
      bash /opt/runtime/geminipod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.gemini /opt/devpod-skel/.gemini \
    && chmod -R a+rX /opt/devpod-skel

ENV OHMYDEVPOD_GEMINI_VERSION=0.37.1
ENV OHMYDEVPOD_GEMINI_REAL_BIN=/usr/local/bin/gemini-real
