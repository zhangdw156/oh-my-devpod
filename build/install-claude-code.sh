#!/usr/bin/env bash
set -euo pipefail

claude_install_home="${OHMYDEVPOD_CLAUDE_INSTALL_HOME:?missing OHMYDEVPOD_CLAUDE_INSTALL_HOME}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
version="${OHMYDEVPOD_CLAUDE_CODE_VERSION:-}"
bucket_url="${OHMYDEVPOD_CLAUDE_CODE_BUCKET_URL:-https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases}"

if [[ -z "${version}" || "${version}" == "latest" ]]; then
  version="$(curl -fsSL https://registry.npmjs.org/@anthropic-ai/claude-code/latest | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
  if [[ -z "${version}" ]]; then
    echo "failed to resolve latest Claude Code version from npm registry" >&2
    exit 1
  fi
  echo "Resolved latest Claude Code version: ${version}"
fi
manifest_url="${bucket_url}/${version}/manifest.json"
native_versions_dir="${claude_install_home}/.local/share/claude/versions"
real_bin="${native_versions_dir}/${version}"
metadata_file="${claude_install_home}/.claude.json"

mkdir -p "${bin_dir}"
mkdir -p "${native_versions_dir}"

arch="$(uname -m)"
case "${arch}" in
  x86_64|amd64)
    arch_suffix="x64"
    ;;
  aarch64|arm64)
    arch_suffix="arm64"
    ;;
  *)
    echo "unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

libc_suffix=""
if ldd --version 2>&1 | grep -qi musl; then
  libc_suffix="-musl"
fi

platform="linux-${arch_suffix}${libc_suffix}"
binary_url="${bucket_url}/${version}/${platform}/claude"

manifest_json="$(curl -fsSL "${manifest_url}")"
expected_sha="$(printf '%s' "${manifest_json}" | jq -r --arg p "${platform}" '.[$p].checksum // empty')"
if [[ -z "${expected_sha}" ]]; then
  echo "failed to extract checksum for platform ${platform} from manifest" >&2
  exit 1
fi

if [[ ! -x "${real_bin}" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT
  curl -fsSL "${binary_url}" -o "${tmp_dir}/claude"
  actual_sha="$(sha256sum "${tmp_dir}/claude" | awk "{print \$1}")"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "checksum mismatch for Claude Code ${version} (${platform})" >&2
    echo "expected: ${expected_sha}" >&2
    echo "actual:   ${actual_sha}" >&2
    exit 1
  fi
  install -m 0755 "${tmp_dir}/claude" "${real_bin}"
fi

ln -sfn "${real_bin}" "${bin_dir}/claude-real"

cat > "${metadata_file}" <<EOF
{
  "installMethod": "native",
  "autoUpdates": false
}
EOF
