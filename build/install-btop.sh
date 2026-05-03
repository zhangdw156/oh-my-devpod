#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="v1.4.6"
asset_root="${OHMYDEVPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/btop/${version}"
bin_dir="${OHMYDEVPOD_BIN_DIR:-/usr/local/bin}"
btop_dir="${OHMYDEVPOD_BTOP_DIR:-/opt/btop}"

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
archive_path="${asset_dir}/${archive_name}"
checksum_file="${asset_dir}/SHA256SUMS"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

expected_sha="$(awk -v name="${archive_name}" '$2 == name {print $1}' "${checksum_file}")"
actual_sha="$(sha256sum "${archive_path}" | awk '{print $1}')"

if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for btop ${version} (${btop_arch})" >&2
  echo "Expected: ${expected_sha:-missing}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

mkdir -p "${bin_dir}"
rm -rf "${btop_dir}"
mkdir -p "$(dirname "${btop_dir}")"

tar -xjf "${archive_path}" -C "${tmp_dir}"
mv "${tmp_dir}/btop" "${btop_dir}"
ln -sf "${btop_dir}/bin/btop" "${bin_dir}/btop"

test -x "${bin_dir}/btop"
