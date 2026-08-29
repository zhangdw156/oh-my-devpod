#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="jq"
formula="jq"
command_name="jq"

status() { omd_module_formula_status "${formula}" "${command_name}"; }
managed() { omd_module_formula_managed "${component}" "${formula}"; }
install_or_update() {
  local action="$1"
  shift
  omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" "${action}" "$@"
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
