#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

case "${1:-}" in
  install|update) ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac

if ! omd_module_is_managed zsh && ! omd_module_is_managed zsh-config; then
  exit 0
fi

if ! zsh_path="$(omd_module_zsh_path)"; then
  omd_module_info notice "managed Zsh is unavailable; login shell was not changed"
  exit 0
fi

omd_module_set_login_shell "${zsh_path}"
