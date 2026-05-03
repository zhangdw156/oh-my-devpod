#!/usr/bin/env bash
set -euo pipefail

version="${ANTIDOTE_VERSION:-v2.0.10}"
asset_root="${OHMYDEVPOD_ASSET_ROOT:-/opt/vendor/releases}"
asset_dir="${asset_root}/antidote/${version}"
archive_name="antidote-${version}.tar.gz"
archive_path="${asset_dir}/${archive_name}"
checksum_file="${asset_dir}/SHA256SUMS"
antidote_dir="${OHMYDEVPOD_ANTIDOTE_DIR:-/opt/antidote}"

expected_sha="$(awk -v name="${archive_name}" '$2 == name {print $1}' "${checksum_file}")"
actual_sha="$(sha256sum "${archive_path}" | awk '{print $1}')"

if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum mismatch for antidote ${version}" >&2
  echo "Expected: ${expected_sha:-missing}" >&2
  echo "Actual:   ${actual_sha}" >&2
  exit 1
fi

rm -rf "${antidote_dir}"
mkdir -p "${antidote_dir}"
tar -xzf "${archive_path}" --strip-components=1 -C "${antidote_dir}"

test -f "${antidote_dir}/antidote.zsh"
