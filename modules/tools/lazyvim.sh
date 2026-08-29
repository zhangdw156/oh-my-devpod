#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="lazyvim"
config_dir="${OHMYDEVPOD_NVM_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/nvim}"
data_dir="${OHMYDEVPOD_NVM_DATA_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/nvim}"
state_dir="${OHMYDEVPOD_NVM_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/nvim}"
cache_dir="${OHMYDEVPOD_NVM_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/nvim}"
config_marker="${config_dir}/.ohmydevpod-managed.json"

status() {
  [[ -f "${config_dir}/lua/config/lazy.lua" ]] &&
    grep -q 'LazyVim/LazyVim' "${config_dir}/lua/config/lazy.lua"
}

managed() {
  omd_module_marker_matches "${component}" "${config_dir}"
}

install_or_update() {
  local action="$1" repo_root
  shift
  omd_module_reject_unknown_flags "$@" || return
  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} vendored LazyVim configuration at ${config_dir}"
    return 0
  fi
  repo_root="$(omd_module_repo_root)"
  OHMYDEVPOD_LAZYVIM_SOURCE_DIR="${repo_root}/vendor/nvim/lazyvim-starter" \
    OHMYDEVPOD_NVM_OVERLAY_DIR="${repo_root}/config/nvim" \
    OHMYDEVPOD_NVM_CONFIG_DIR="${config_dir}" \
    OHMYDEVPOD_NVM_DATA_DIR="${data_dir}" \
    OHMYDEVPOD_NVM_STATE_DIR="${state_dir}" \
    OHMYDEVPOD_NVM_CACHE_DIR="${cache_dir}" \
    bash "${repo_root}/build/install-lazyvim.sh"
  omd_module_mark_managed "${component}" configuration "${config_dir}"
}

uninstall() {
  local preserved
  omd_module_require_managed_uninstall "${component}" managed "$@" || return
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed LazyVim configuration; preserve backups, data, state, and cache"
    return 0
  fi
  if [[ ! -f "${config_marker}" ]] ||
    ! grep -q '"managed_by":[[:space:]]*"oh-my-devpod"' "${config_marker}"; then
    omd_module_info error "LazyVim config marker is missing; refusing to remove ${config_dir}"
    return 1
  fi
  preserved="$(omd_module_state_dir)/backups/${component}/uninstall-$(date -u +%Y%m%d%H%M%SZ)"
  mkdir -p "$(dirname "${preserved}")"
  mv "${config_dir}" "${preserved}"
  omd_module_info notice "preserved managed LazyVim configuration at ${preserved}"
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
