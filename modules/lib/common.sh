#!/usr/bin/env bash
# Shared helpers for oh-my-devpod component modules.

omd_module_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." && pwd
}

omd_module_bin_dir() {
  printf '%s\n' "${OHMYDEVPOD_BIN_DIR:-${HOME}/.local/bin}"
}

omd_module_prefix() {
  printf '%s\n' "${OHMYDEVPOD_PREFIX:-${HOME}/.local/share/oh-my-devpod}"
}

omd_module_info() {
  local level="$1" message="$2"
  printf '%s: %s\n' "${level}" "${message}"
}

omd_module_has_flag() {
  local needle="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "${needle}" ]] && return 0
  done
  return 1
}

omd_module_dry_run() {
  omd_module_has_flag --dry-run "$@"
}

omd_module_required_uninstall() {
  local name="$1"
  omd_module_info error "${name} is required and cannot be uninstalled by the normal flow"
  return 2
}

omd_module_unknown_action() {
  local action="${1:-}"
  omd_module_info error "unknown action: ${action:-<empty>}"
  return 2
}

omd_module_require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    omd_module_info error "missing required command: ${cmd}"
    return 1
  fi
}

omd_module_require_npm() {
  omd_module_require_command node
  omd_module_require_command npm
  local node_major
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
  if [[ -z "${node_major}" || "${node_major}" -lt 20 ]]; then
    omd_module_info error "Node.js >=20 is required; found $(node --version 2>/dev/null || echo missing)"
    return 1
  fi
}

omd_module_install_npm_tool() {
  local package_name="$1" command_name="$2" prefix_name="$3"
  local bin_dir prefix install_prefix
  bin_dir="$(omd_module_bin_dir)"
  prefix="$(omd_module_prefix)"
  install_prefix="${prefix}/opt/${prefix_name}"

  mkdir -p "${bin_dir}" "${install_prefix}"
  npm install -g --prefix "${install_prefix}" "${package_name}"
  ln -sfn "${install_prefix}/bin/${command_name}" "${bin_dir}/${command_name}"
}

omd_module_uninstall_npm_tool() {
  local command_name="$1" prefix_name="$2"
  local bin_dir prefix install_prefix
  bin_dir="$(omd_module_bin_dir)"
  prefix="$(omd_module_prefix)"
  install_prefix="${prefix}/opt/${prefix_name}"

  rm -f "${bin_dir}/${command_name}"
  rm -rf "${install_prefix}"
}
