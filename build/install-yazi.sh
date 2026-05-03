#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="v26.1.22"
asset_root="${OHMYDEVPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/yazi/${version}"
bin_dir="${OHMYDEVPOD_BIN_DIR:-/usr/local/bin}"

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
asset_path="${asset_dir}/${asset_name}"
checksum_file="${asset_dir}/SHA256SUMS"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

expected_sha="$(awk -v name="${asset_name}" '$2 == name {print $1}' "${checksum_file}")"
actual_sha="$(sha256sum "${asset_path}" | awk '{print $1}')"

if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for yazi ${version} (${yazi_arch})" >&2
  echo "Expected: ${expected_sha:-missing}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

mkdir -p "${bin_dir}"

# Extract the upstream package payload into a staging directory so bootstrap mode
# can install Yazi without writing directly into /. Keep only the core binaries.
dpkg-deb -x "${asset_path}" "${tmp_dir}/root"
install -m 0755 "${tmp_dir}/root/usr/bin/yazi" "${bin_dir}/yazi"
install -m 0755 "${tmp_dir}/root/usr/bin/ya" "${bin_dir}/ya"

test -x "${bin_dir}/yazi"
test -x "${bin_dir}/ya"
