#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="zsh"
formula="zsh"
command_name="zsh"

status() { omd_module_formula_status "${formula}" "${command_name}"; }
managed() { omd_module_formula_managed "${component}" "${formula}"; }
install_or_update() {
  local action="$1" zsh_path
  shift
  if omd_module_dry_run "$@"; then
    omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" "${action}" "$@"
    omd_module_info plan "set the current user's login shell to Zsh"
    return 0
  fi
  omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" "${action}" "$@"
  zsh_path="$(omd_module_zsh_path)"
  omd_module_set_login_shell "${zsh_path}"
}
uninstall() { omd_module_formula_uninstall "${component}" "${formula}" "$@"; }

case "${1:-}" in
  status) status ;;
  managed) managed ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; uninstall "$@" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
