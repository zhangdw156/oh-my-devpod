#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="v18.15.2"
asset_root="${OPENPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/atuin/${version}"
bin_dir="${OPENPOD_BIN_DIR:-/usr/local/bin}"

if [[ -z "${target_arch}" ]]; then
  target_arch="$(dpkg --print-architecture)"
fi

case "${target_arch}" in
  amd64|x86_64)
    atuin_arch="x86_64"
    ;;
  arm64|aarch64)
    atuin_arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture for atuin: ${target_arch}" >&2
    exit 1
    ;;
esac

archive_name="atuin-${atuin_arch}-unknown-linux-musl.tar.gz"
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
  echo "Checksum mismatch for atuin ${version} (${atuin_arch})" >&2
  echo "Expected: ${expected_sha:-missing}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

tar -xzf "${archive_path}" -C "${tmp_dir}"

mkdir -p "${bin_dir}"
install -m 0755 "${tmp_dir}/atuin" "${bin_dir}/atuin"

test -x "${bin_dir}/atuin"
