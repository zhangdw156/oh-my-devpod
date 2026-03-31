#!/usr/bin/env bash
set -euo pipefail

version="${ZELLIJ_VERSION:-latest}"
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
    zellij_arch="x86_64"
    ;;
  arm64|aarch64)
    zellij_arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture for zellij: ${target_arch}" >&2
    exit 1
    ;;
esac

asset_name="zellij-${zellij_arch}-unknown-linux-musl"
archive_name="${asset_name}.tar.gz"
checksum_name="${asset_name}.sha256sum"

if [[ "${version}" == "latest" ]]; then
  release_json="$("${curl_retry[@]}" https://api.github.com/repos/zellij-org/zellij/releases/latest)"
  version="$(printf '%s' "${release_json}" | sed -nE 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)"
else
  release_json=""
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

release_url="https://github.com/zellij-org/zellij/releases/download/${version}"

"${curl_retry[@]}" "${release_url}/${archive_name}" -o "${tmp_dir}/${archive_name}"
"${curl_retry[@]}" "${release_url}/${checksum_name}" -o "${tmp_dir}/${checksum_name}"

tar -xzf "${tmp_dir}/${archive_name}" -C "${tmp_dir}"

expected_sha="$(awk '{print $1}' "${tmp_dir}/${checksum_name}")"
actual_sha="$(sha256sum "${tmp_dir}/zellij" | awk '{print $1}')"

if [[ "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for zellij ${version} (${zellij_arch})" >&2
  echo "Expected: ${expected_sha}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

install -m 0755 "${tmp_dir}/zellij" /usr/local/bin/zellij
