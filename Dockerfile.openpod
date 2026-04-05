ARG DEVPOD_BASE_IMAGE=devpod
FROM ${DEVPOD_BASE_IMAGE}

COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > /etc/ld-musl-x86_64.path

COPY runtime/openpod/vendor/opencode /opt/vendor/opencode
COPY runtime/openpod/config/opencode.json /root/.config/opencode/config.json
COPY runtime/openpod/bin/openpod-shell /usr/local/bin/openpod-shell
RUN mkdir -p /root/.config/opencode/plugins \
    && ln -sf /opt/vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js /root/.config/opencode/plugins/superpowers.js \
    && ln -sfn /opt/vendor/opencode/skills /root/.config/opencode/skills \
    && chmod 0755 /usr/local/bin/openpod-shell
