#!/usr/bin/env bash
set -euo pipefail

repo_root="${OPENPOD_REPO_ROOT:?missing OPENPOD_REPO_ROOT}"
prefix="${OPENPOD_PREFIX:?missing OPENPOD_PREFIX}"
bin_dir="${OPENPOD_BIN_DIR:?missing OPENPOD_BIN_DIR}"
config_home="${OPENPOD_CONFIG_HOME:?missing OPENPOD_CONFIG_HOME}"
copilot_prefix="${prefix}/opt/copilot-cli"
copilot_version="${OPENPOD_COPILOT_VERSION:-1.0.24}"
skills_root="${repo_root}/runtime/copilotpod/skills"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "copilotpod bootstrap requires node and npm to be preinstalled" >&2
  exit 1
fi

mkdir -p "${copilot_prefix}" "${config_home}"
npm install -g --prefix "${copilot_prefix}" "@github/copilot@${copilot_version}"
ln -sfn "${copilot_prefix}/bin/copilot" "${bin_dir}/copilot-real"
ln -sfn "${skills_root}" "${config_home}/skills"

install -m 0755 "${repo_root}/runtime/copilotpod/bin/copilot" "${bin_dir}/copilot"
install -m 0755 "${repo_root}/runtime/copilotpod/bin/copilotpod-shell" "${bin_dir}/copilotpod-shell"
