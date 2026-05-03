#!/usr/bin/env bash
set -euo pipefail

target_arch="${TARGETARCH:-}"
version="${NEOVIM_VERSION:-v0.12.0}"
asset_root="${OHMYDEVPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/neovim/${version}"
bin_dir="${OHMYDEVPOD_BIN_DIR:-/usr/local/bin}"
neovim_dir="${OHMYDEVPOD_NEOVIM_DIR:-/opt/neovim}"

if [[ -z "${target_arch}" ]]; then
  target_arch="$(dpkg --print-architecture)"
fi

case "${target_arch}" in
  amd64|x86_64)
    neovim_arch="x86_64"
    ;;
  arm64|aarch64)
    neovim_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture for neovim: ${target_arch}" >&2
    exit 1
    ;;
esac

archive_name="nvim-linux-${neovim_arch}.tar.gz"
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
  echo "Checksum mismatch for neovim ${version} (${neovim_arch})" >&2
  echo "Expected: ${expected_sha:-missing}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

tar -xzf "${archive_path}" -C "${tmp_dir}"

mkdir -p "${bin_dir}" "$(dirname "${neovim_dir}")"
rm -rf "${neovim_dir}"
mv "${tmp_dir}/nvim-linux-${neovim_arch}" "${neovim_dir}"
ln -sfn "${neovim_dir}/bin/nvim" "${bin_dir}/nvim"

test -x "${bin_dir}/nvim"
test -x "${neovim_dir}/bin/nvim"
test -d "${neovim_dir}/share/nvim/runtime"
