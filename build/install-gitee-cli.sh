#!/usr/bin/env bash
set -euo pipefail

api_base="${OHMYDEVPOD_GITEE_CLI_API_BASE:-https://gitee.com/api/v5}"
release_base="${OHMYDEVPOD_GITEE_CLI_RELEASE_BASE:-https://gitee.com/oschina/gitee-cli/releases/download}"
requested_version="${OHMYDEVPOD_GITEE_CLI_VERSION:-latest}"
bin_dir="${OHMYDEVPOD_BIN_DIR:-${HOME}/.local/bin}"
target_arch="${TARGETARCH:-}"
repo="oschina/gitee-cli"
staged_path=""
tar_version=""

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

download() {
  local url="$1" destination="$2"
  curl \
    -fsSL \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 15 \
    --max-time 300 \
    "${url}" \
    -o "${destination}"
}

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${path}" | awk '{print $1}'
  else
    fail "sha256sum or shasum is required"
  fi
}

json_field() {
  local key="$1"
  grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" |
    sed 's/^[^:]*:[[:space:]]*"\([^"]*\)"$/\1/' |
    head -n 1
}

if [[ -z "${target_arch}" ]]; then
  target_arch="$(uname -m)"
fi

case "${target_arch}" in
  amd64|x86_64)
    release_arch="amd64"
    ;;
  arm64|aarch64)
    release_arch="arm64"
    ;;
  *)
    fail "unsupported architecture for Gitee CLI: ${target_arch}"
    ;;
esac

if [[ "${requested_version}" == "latest" ]]; then
  release_endpoint="${api_base}/repos/${repo}/releases/latest"
else
  release_tag="${requested_version}"
  [[ "${release_tag}" == v* ]] || release_tag="v${release_tag}"
  release_endpoint="${api_base}/repos/${repo}/releases/tags/${release_tag}"
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
  [[ -z "${staged_path}" ]] || rm -f "${staged_path}"
}
trap cleanup EXIT

release_json_path="${tmp_dir}/release.json"
download "${release_endpoint}" "${release_json_path}" ||
  fail "failed to fetch Gitee CLI release metadata"
release_json="$(cat "${release_json_path}")"
release_tag="$(printf '%s' "${release_json}" | json_field tag_name)"
[[ "${release_tag}" =~ ^v[0-9][0-9A-Za-z.-]*$ ]] ||
  fail "invalid Gitee CLI release tag: ${release_tag:-missing}"

release_version="${release_tag#v}"
archive_name="gitee_${release_version}_linux_${release_arch}.tar.gz"
archive_url="${release_base}/${release_tag}/${archive_name}"
checksums_url="${release_base}/${release_tag}/checksums.txt"

archive_path="${tmp_dir}/${archive_name}"
checksums_path="${tmp_dir}/checksums.txt"
download "${archive_url}" "${archive_path}" ||
  fail "failed to download ${archive_name}"
download "${checksums_url}" "${checksums_path}" ||
  fail "failed to download checksums.txt"

expected_sha="$(
  awk -v name="${archive_name}" \
    '$2 == name || $2 == "./" name {print $1}' \
    "${checksums_path}" |
    head -n 1
)"
[[ "${expected_sha}" =~ ^[[:xdigit:]]{64}$ ]] ||
  fail "checksums.txt has no valid SHA-256 entry for ${archive_name}"
actual_sha="$(sha256_file "${archive_path}")"
[[ "${actual_sha}" == "${expected_sha}" ]] ||
  fail "checksum mismatch for ${archive_name}"

extract_dir="${tmp_dir}/extract"
mkdir -p "${extract_dir}"
tar_extract_args=(-xzf "${archive_path}" -C "${extract_dir}")
tar_version="$(tar --version 2>/dev/null || true)"
if [[ "${tar_version%%$'\n'*}" == *"GNU tar"* ]]; then
  tar_extract_args=(--warning=no-unknown-keyword "${tar_extract_args[@]}")
fi
tar "${tar_extract_args[@]}" gitee ||
  fail "failed to extract Gitee CLI binary"
[[ -f "${extract_dir}/gitee" && ! -L "${extract_dir}/gitee" ]] ||
  fail "release archive does not contain a regular gitee binary"
chmod 0755 "${extract_dir}/gitee"

version_output="$("${extract_dir}/gitee" --version 2>&1)" ||
  fail "downloaded Gitee CLI binary failed validation"
version_matches=false
for version_token in ${version_output}; do
  version_token="${version_token#v}"
  if [[ "${version_token}" == "${release_version}" ]]; then
    version_matches=true
    break
  fi
done
[[ "${version_matches}" == "true" ]] ||
  fail "downloaded Gitee CLI version does not match ${release_tag}"

mkdir -p "${bin_dir}"
[[ ! -d "${bin_dir}/gitee" ]] ||
  fail "refusing to replace directory: ${bin_dir}/gitee"
staged_path="${bin_dir}/.gitee.tmp.$$"
install -m 0755 "${extract_dir}/gitee" "${staged_path}"
mv -f "${staged_path}" "${bin_dir}/gitee"
staged_path=""
[[ -f "${bin_dir}/gitee" && -x "${bin_dir}/gitee" ]]

printf 'Installed Gitee CLI %s to %s\n' "${release_tag}" "${bin_dir}/gitee"
