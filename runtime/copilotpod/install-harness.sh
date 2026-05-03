#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHMYDEVPOD_REPO_ROOT:?missing OHMYDEVPOD_REPO_ROOT}"
prefix="${OHMYDEVPOD_PREFIX:?missing OHMYDEVPOD_PREFIX}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
config_home="${OHMYDEVPOD_CONFIG_HOME:?missing OHMYDEVPOD_CONFIG_HOME}"
copilot_prefix="${prefix}/opt/copilot-cli"
copilot_version="${OHMYDEVPOD_COPILOT_VERSION:-}"
skills_root="${repo_root}/runtime/copilotpod/skills"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "copilotpod harness installation requires node and npm to be preinstalled" >&2
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ -z "${node_major}" || "${node_major}" -lt 20 ]]; then
  echo "copilotpod requires Node.js >=20; found $(node --version)" >&2
  exit 1
fi

mkdir -p "${copilot_prefix}" "${config_home}"
copilot_pkg="@github/copilot"
[[ -n "${copilot_version}" ]] && copilot_pkg="${copilot_pkg}@${copilot_version}"
npm install -g --prefix "${copilot_prefix}" "${copilot_pkg}"
ln -sfn "${copilot_prefix}/bin/copilot" "${bin_dir}/copilot-real"
rm -rf "${config_home}/skills"
cp -a "${skills_root}" "${config_home}/skills"

install -m 0755 "${repo_root}/runtime/copilotpod/bin/copilot" "${bin_dir}/copilot"
install -m 0755 "${repo_root}/runtime/copilotpod/bin/copilotpod-shell" "${bin_dir}/copilotpod-shell"
install -m 0755 "${repo_root}/runtime/copilotpod/bin/copilotpod-upgrade" "${bin_dir}/copilotpod-upgrade"
