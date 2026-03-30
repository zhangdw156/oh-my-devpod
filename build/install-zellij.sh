#!/usr/bin/env bash
set -euo pipefail

version="${ZELLIJ_VERSION:-v0.44.0}"
target_arch="${TARGETARCH:-}"

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
release_url="https://github.com/zellij-org/zellij/releases/download/${version}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

curl -fsSL "${release_url}/${archive_name}" -o "${tmp_dir}/${archive_name}"
curl -fsSL "${release_url}/${checksum_name}" -o "${tmp_dir}/${checksum_name}"

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
