#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="yazi"
bin_dir="$(omd_module_bin_dir)"
yazi_bin="${bin_dir}/yazi"
ya_bin="${bin_dir}/ya"

status() {
  if managed; then
    [[ -x "${yazi_bin}" ]] && [[ -x "${ya_bin}" ]]
  else
    command -v yazi >/dev/null 2>&1 || [[ -x "${yazi_bin}" ]]
  fi
}
managed() {
  omd_module_marker_matches "${component}" "${yazi_bin},${ya_bin}"
}

install_or_update() {
  local action="$1" repo_root
  shift
  omd_module_reject_unknown_flags "$@" || return
  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if { omd_module_path_exists "${yazi_bin}" || omd_module_path_exists "${ya_bin}"; } &&
    ! managed; then
    omd_module_info error "refusing to overwrite unmanaged Yazi launcher paths in ${bin_dir}"
    return 1
  fi
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} vendored Yazi binaries at ${bin_dir}"
    return 0
  fi
  repo_root="$(omd_module_repo_root)"
  OHMYDEVPOD_ASSET_ROOT="${OHMYDEVPOD_ASSET_ROOT:-${repo_root}/vendor/releases}" \
    OHMYDEVPOD_BIN_DIR="${bin_dir}" \
    bash "${repo_root}/build/install-yazi.sh"
  omd_module_mark_managed "${component}" binaries "${yazi_bin},${ya_bin}"
}

uninstall() {
  omd_module_require_managed_uninstall "${component}" managed "$@" || return
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed Yazi binaries ${yazi_bin} and ${ya_bin}"
    return 0
  fi
  rm -f "${yazi_bin}" "${ya_bin}"
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
