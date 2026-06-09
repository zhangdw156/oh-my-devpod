#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

status() { command -v copilot >/dev/null 2>&1 || [[ -x "$(omd_module_bin_dir)/copilot" ]]; }
install_or_update() {
  local action="$1" package_name="@github/copilot"
  shift
  [[ -z "${OHMYDEVPOD_COPILOT_VERSION:-}" ]] || package_name="${package_name}@${OHMYDEVPOD_COPILOT_VERSION}"
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} ${package_name} into oh-my-devpod managed prefix"
    return 0
  fi
  omd_module_require_npm
  omd_module_install_npm_tool "${package_name}" copilot copilot-cli
}
uninstall() {
  shift || true
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed copilot package and symlink only; keep GitHub auth state"
    return 0
  fi
  omd_module_uninstall_npm_tool copilot copilot-cli
}
case "${1:-}" in
  status) status ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) uninstall "$@" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
