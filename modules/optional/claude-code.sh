#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

status() { command -v claude >/dev/null 2>&1 || [[ -x "$(omd_module_bin_dir)/claude" ]]; }

install_or_update() {
  local action="$1" repo_root bin_dir
  shift
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} Claude Code binary and managed claude launcher"
    return 0
  fi
  repo_root="$(omd_module_repo_root)"
  bin_dir="$(omd_module_bin_dir)"
  mkdir -p "${bin_dir}"
  OHMYDEVPOD_BIN_DIR="${bin_dir}" \
  OHMYDEVPOD_CLAUDE_INSTALL_HOME="${HOME}" \
  bash "${repo_root}/build/install-claude-code.sh"
  ln -sfn "${bin_dir}/claude-real" "${bin_dir}/claude"
}

uninstall() {
  shift || true
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed claude launchers only; keep ~/.claude, ~/.claude.json, caches, and auth"
    return 0
  fi
  rm -f "$(omd_module_bin_dir)/claude" "$(omd_module_bin_dir)/claude-real"
}

case "${1:-}" in
  status) status ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) uninstall "$@" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
