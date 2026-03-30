#!/usr/bin/env bash
set -euo pipefail

version="${ANTIDOTE_VERSION:-latest}"
curl_retry=(
  curl
  -fsSL
  --retry 5
  --retry-delay 2
  --retry-connrefused
  --connect-timeout 15
)

if [[ "${version}" == "latest" ]]; then
  release_json="$("${curl_retry[@]}" https://api.github.com/repos/mattmc3/antidote/releases/latest)"
  version="$(printf '%s' "${release_json}" | sed -nE 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)"
fi

archive_url="https://codeload.github.com/mattmc3/antidote/tar.gz/refs/tags/${version}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

"${curl_retry[@]}" "${archive_url}" -o "${tmp_dir}/antidote.tar.gz"

rm -rf /opt/antidote
mkdir -p /opt/antidote
tar -xzf "${tmp_dir}/antidote.tar.gz" --strip-components=1 -C /opt/antidote

test -f /opt/antidote/antidote.zsh
