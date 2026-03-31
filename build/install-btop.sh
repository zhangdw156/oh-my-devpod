#!/usr/bin/env bash
set -euo pipefail

version="${BTOP_VERSION:-latest}"
target_arch="${TARGETARCH:-}"
curl_retry=(
  curl
  -fsSL
  --retry 5
  --retry-delay 2
  --retry-connrefused
  --connect-timeout 15
)

if [[ -z "${target_arch}" ]]; then
  target_arch="$(dpkg --print-architecture)"
fi

case "${target_arch}" in
  amd64|x86_64)
    btop_arch="x86_64"
    ;;
  arm64|aarch64)
    btop_arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture for btop: ${target_arch}" >&2
    exit 1
    ;;
esac

archive_name="btop-${btop_arch}-unknown-linux-musl.tbz"

if [[ "${version}" == "latest" ]]; then
  release_url="https://github.com/aristocratos/btop/releases/latest/download"
else
  release_url="https://github.com/aristocratos/btop/releases/download/${version}"
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

"${curl_retry[@]}" "${release_url}/${archive_name}" -o "${tmp_dir}/btop.tbz"
tar -xjf "${tmp_dir}/btop.tbz" -C "${tmp_dir}"

rm -rf /opt/btop
mv "${tmp_dir}/btop" /opt/btop
ln -sf /opt/btop/bin/btop /usr/local/bin/btop

test -x /usr/local/bin/btop
