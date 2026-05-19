#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="${WITR_VERSION:-v0.3.2}"
asset_root="${OHMYDEVPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/witr/${version}"
bin_dir="${OHMYDEVPOD_BIN_DIR:-/usr/local/bin}"

if [[ -z "${target_arch}" ]]; then
  target_arch="$(dpkg --print-architecture)"
fi

case "${target_arch}" in
  amd64|x86_64)
    witr_arch="amd64"
    ;;
  arm64|aarch64)
    witr_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture for witr: ${target_arch}" >&2
    exit 1
    ;;
esac

asset_name="witr-linux-${witr_arch}"
asset_path="${asset_dir}/${asset_name}"
checksum_path="${asset_dir}/SHA256SUMS"

expected_sha="$(awk -v name="${asset_name}" '$2 == name || $2 == "*" name {print $1; exit}' "${checksum_path}")"
actual_sha="$(sha256sum "${asset_path}" | awk '{print $1}')"

if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for witr ${version} (${witr_arch})" >&2
  echo "Expected: ${expected_sha}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

mkdir -p "${bin_dir}"
install -m 0755 "${asset_path}" "${bin_dir}/witr"
