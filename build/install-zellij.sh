#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="v0.44.0"
asset_root="${OPENPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/zellij/${version}"
bin_dir="${OPENPOD_BIN_DIR:-/usr/local/bin}"

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
archive_path="${asset_dir}/${archive_name}"
checksum_path="${asset_dir}/${checksum_name}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

tar -xzf "${archive_path}" -C "${tmp_dir}"

expected_sha="$(awk '{print $1}' "${checksum_path}")"
actual_sha="$(sha256sum "${tmp_dir}/zellij" | awk '{print $1}')"

if [[ "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for zellij ${version} (${zellij_arch})" >&2
  echo "Expected: ${expected_sha}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

mkdir -p "${bin_dir}"
install -m 0755 "${tmp_dir}/zellij" "${bin_dir}/zellij"
