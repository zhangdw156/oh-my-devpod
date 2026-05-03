#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHMYDEVPOD_REPO_ROOT:?missing OHMYDEVPOD_REPO_ROOT}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
config_home="${OHMYDEVPOD_CONFIG_HOME:?missing OHMYDEVPOD_CONFIG_HOME}"

mkdir -p "${config_home}"
export OHMYDEVPOD_BIN_DIR="${bin_dir}"
export OHMYDEVPOD_CLAUDE_INSTALL_HOME="${HOME}"
export OHMYDEVPOD_CLAUDE_CODE_VERSION="${OHMYDEVPOD_CLAUDE_CODE_VERSION:-}"

bash "${repo_root}/build/install-claude-code.sh"

if [[ -d "${repo_root}/runtime/claudepod/skills" ]]; then
  rm -rf "${config_home}/skills"
  cp -a "${repo_root}/runtime/claudepod/skills" "${config_home}/skills"
fi

install -m 0755 "${repo_root}/runtime/claudepod/bin/claude" "${bin_dir}/claude"
install -m 0755 "${repo_root}/runtime/claudepod/bin/claudepod-shell" "${bin_dir}/claudepod-shell"
install -m 0755 "${repo_root}/runtime/claudepod/bin/claudepod-upgrade" "${bin_dir}/claudepod-upgrade"
