#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="zsh"
formula="zsh"
command_name="zsh"

status() { omd_module_formula_status "${formula}" "${command_name}"; }
managed() { omd_module_formula_managed "${component}" "${formula}"; }
uninstall() { omd_module_formula_uninstall "${component}" "${formula}" "$@"; }

case "${1:-}" in
  status) status ;;
  managed) managed ;;
  install) shift; omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" install "$@" ;;
  update) shift; omd_module_formula_install_or_update "${component}" "${formula}" "${command_name}" update "$@" ;;
  uninstall) shift; uninstall "$@" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
