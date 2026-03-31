#!/usr/bin/env bash
set -euo pipefail

version="${YAZI_VERSION:-latest}"
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
    yazi_arch="x86_64"
    ;;
  arm64|aarch64)
    yazi_arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture for yazi: ${target_arch}" >&2
    exit 1
    ;;
esac

asset_name="yazi-${yazi_arch}-unknown-linux-gnu.deb"

if [[ "${version}" == "latest" ]]; then
  release_url="https://github.com/sxyazi/yazi/releases/latest/download"
else
  release_url="https://github.com/sxyazi/yazi/releases/download/${version}"
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

"${curl_retry[@]}" "${release_url}/${asset_name}" -o "${tmp_dir}/yazi.deb"
dpkg -i "${tmp_dir}/yazi.deb"

test -x /usr/bin/yazi
test -x /usr/bin/ya
