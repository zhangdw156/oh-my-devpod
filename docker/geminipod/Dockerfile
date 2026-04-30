ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY runtime/geminipod /opt/runtime/geminipod
RUN OPENPOD_REPO_ROOT=/opt OPENPOD_PREFIX=/opt/geminipod OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CONFIG_HOME=/root/.gemini \
      bash /opt/runtime/geminipod/install-harness.sh

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.gemini /opt/devpod-skel/.gemini \
    && chmod -R a+rX /opt/devpod-skel

ENV OPENPOD_GEMINI_VERSION=0.37.1
ENV OPENPOD_GEMINI_REAL_BIN=/usr/local/bin/gemini-real
