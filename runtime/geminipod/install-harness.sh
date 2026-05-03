#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHMYDEVPOD_REPO_ROOT:?missing OHMYDEVPOD_REPO_ROOT}"
prefix="${OHMYDEVPOD_PREFIX:?missing OHMYDEVPOD_PREFIX}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
config_home="${OHMYDEVPOD_CONFIG_HOME:?missing OHMYDEVPOD_CONFIG_HOME}"
gemini_prefix="${prefix}/opt/gemini-cli"
gemini_version="${OHMYDEVPOD_GEMINI_VERSION:-0.37.1}"
skills_root="${repo_root}/runtime/geminipod/skills"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "geminipod bootstrap requires Node.js >=20 and npm to be preinstalled" >&2
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ -z "${node_major}" || "${node_major}" -lt 20 ]]; then
  echo "geminipod requires Node.js >=20; found $(node --version)" >&2
  exit 1
fi

mkdir -p "${gemini_prefix}" "${config_home}"
if [[ ! -f "${config_home}/projects.json" ]]; then
  printf "{}\n" > "${config_home}/projects.json"
fi
npm install -g --prefix "${gemini_prefix}" "@google/gemini-cli@${gemini_version}"
ln -sfn "${gemini_prefix}/bin/gemini" "${bin_dir}/gemini-real"
ln -sfn "${skills_root}" "${config_home}/skills"

install -m 0755 "${repo_root}/runtime/geminipod/bin/gemini" "${bin_dir}/gemini"
install -m 0755 "${repo_root}/runtime/geminipod/bin/geminipod-shell" "${bin_dir}/geminipod-shell"
