#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
# shellcheck source=../lib/source-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/source-config.sh"

component="micromamba"
formula="micromamba"
command_name="micromamba"

status() { omd_module_formula_status "${formula}" "${command_name}"; }
managed() { omd_module_formula_managed "${component}" "${formula}"; }
install_or_update() {
  local action="$1"
  shift
  omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" "${action}" "$@"
}
uninstall() {
  if omd_module_dry_run "$@"; then
    omd_module_formula_uninstall "${component}" "${formula}" "$@"
    return
  fi
  omd_module_formula_uninstall_keep_marker "${component}" "${formula}" "$@" || return
  omd_source_config_remove_component "${component}" || return
  omd_module_unmark_managed "${component}"
}

case "${1:-}" in
  status) status ;;
  managed) managed ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; uninstall "$@" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
