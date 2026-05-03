#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHMYDEVPOD_REPO_ROOT:?missing OHMYDEVPOD_REPO_ROOT}"
prefix="${OHMYDEVPOD_PREFIX:?missing OHMYDEVPOD_PREFIX}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
config_home="${OHMYDEVPOD_CONFIG_HOME:?missing OHMYDEVPOD_CONFIG_HOME}"
codex_prefix="${prefix}/opt/codex-cli"
codex_version="${OHMYDEVPOD_CODEX_VERSION:-0.118.0}"
skills_root="${repo_root}/runtime/codexpod/skills"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "codexpod bootstrap requires node and npm to be preinstalled" >&2
  exit 1
fi

mkdir -p "${codex_prefix}" "${config_home}"
npm install -g --prefix "${codex_prefix}" "@openai/codex@${codex_version}"
ln -sfn "${codex_prefix}/bin/codex" "${bin_dir}/codex-real"
ln -sfn "${skills_root}" "${config_home}/skills"

install -m 0755 "${repo_root}/runtime/codexpod/bin/codex" "${bin_dir}/codex"
install -m 0755 "${repo_root}/runtime/codexpod/bin/codexpod-shell" "${bin_dir}/codexpod-shell"
