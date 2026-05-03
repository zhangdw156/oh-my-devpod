ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

ARG TARGETARCH
COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN musl_arch="$(case "${TARGETARCH:-$(dpkg --print-architecture)}" in amd64|x86_64) echo x86_64;; arm64|aarch64) echo aarch64;; *) echo x86_64;; esac)" \
    && echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > "/etc/ld-musl-${musl_arch}.path"

COPY runtime/openpod/vendor/opencode /opt/vendor/opencode
COPY runtime/openpod/config/opencode.json /root/.config/opencode/config.json
COPY runtime/openpod/bin/openpod-shell /usr/local/bin/openpod-shell
COPY runtime/openpod/bin/openpod-upgrade /usr/local/bin/openpod-upgrade
RUN mkdir -p /root/.config/opencode/plugins \
    && ln -sf /opt/vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js /root/.config/opencode/plugins/superpowers.js \
    && ln -sfn /opt/vendor/opencode/skills /root/.config/opencode/skills \
    && chmod 0755 /usr/local/bin/openpod-shell

# Sync flavor config into devpod-skel for --user support
RUN cp -a /root/.config/opencode /opt/devpod-skel/.config/opencode
