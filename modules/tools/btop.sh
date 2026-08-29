#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="btop"
bin_path="$(omd_module_bin_dir)/btop"
install_dir="${OHMYDEVPOD_BTOP_DIR:-$(omd_module_prefix)/opt/btop}"

status() {
  if managed; then
    [[ -x "${install_dir}/bin/btop" ]] &&
      [[ -L "${bin_path}" ]] &&
      [[ "$(readlink "${bin_path}")" == "${install_dir}/bin/btop" ]]
  else
    command -v btop >/dev/null 2>&1 || [[ -x "${bin_path}" ]]
  fi
}
managed() {
  omd_module_marker_matches "${component}" "${install_dir}"
}

install_or_update() {
  local action="$1" repo_root
  shift
  omd_module_reject_unknown_flags "$@" || return
  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if omd_module_path_exists "${bin_path}" && ! managed; then
    omd_module_info error "refusing to overwrite unmanaged path: ${bin_path}"
    return 1
  fi
  if omd_module_path_exists "${install_dir}" && ! managed; then
    omd_module_info error "refusing to overwrite unmanaged btop directory: ${install_dir}"
    return 1
  fi
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} vendored btop under ${install_dir}"
    return 0
  fi
  repo_root="$(omd_module_repo_root)"
  OHMYDEVPOD_ASSET_ROOT="${OHMYDEVPOD_ASSET_ROOT:-${repo_root}/vendor/releases}" \
    OHMYDEVPOD_BIN_DIR="$(omd_module_bin_dir)" \
    OHMYDEVPOD_BTOP_DIR="${install_dir}" \
    bash "${repo_root}/build/install-btop.sh"
  omd_module_mark_managed "${component}" directory "${install_dir}"
}

uninstall() {
  omd_module_require_managed_uninstall "${component}" managed "$@" || return
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed btop directory and launcher"
    return 0
  fi
  rm -f "${bin_path}"
  omd_module_remove_tree "${install_dir}"
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
