#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="gitee"
bin_path="$(omd_module_bin_dir)/gitee"

marked() {
  omd_module_marker_matches "${component}" "${bin_path}"
}

binary_matches_marker() {
  local expected actual
  [[ -f "${bin_path}" && -x "${bin_path}" ]] || return 1
  expected="$(omd_module_marker_value "${component}" binary_sha256)" || return 1
  [[ "${expected}" =~ ^[[:xdigit:]]{64}$ ]] || return 1
  actual="$(omd_module_sha256_file "${bin_path}")" || return 1
  [[ "${actual}" == "${expected}" ]]
}

status() {
  if marked; then
    [[ -f "${bin_path}" && -x "${bin_path}" ]]
  else
    command -v gitee >/dev/null 2>&1 ||
      [[ -f "${bin_path}" && -x "${bin_path}" ]]
  fi
}

managed() {
  marked || return 1
  [[ ! -e "${bin_path}" ]] || binary_matches_marker
}

install_or_update() {
  local action="$1" repo_root backup_path="" installed_sha
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
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} official Gitee CLI binary at ${bin_path}"
    return 0
  fi

  repo_root="$(omd_module_repo_root)"
  if [[ -f "${bin_path}" ]]; then
    backup_path="$(mktemp "$(dirname "${bin_path}")/.gitee.backup.XXXXXXXX")"
    cp -p "${bin_path}" "${backup_path}"
  fi

  if ! OHMYDEVPOD_BIN_DIR="$(omd_module_bin_dir)" \
    bash "${repo_root}/build/install-gitee-cli.sh"; then
    [[ -z "${backup_path}" ]] || rm -f "${backup_path}"
    return 1
  fi

  if ! installed_sha="$(omd_module_sha256_file "${bin_path}")" ||
    ! omd_module_mark_managed \
      "${component}" \
      binary \
      "${bin_path}" \
      "binary_sha256=${installed_sha}"; then
    if [[ -n "${backup_path}" ]]; then
      mv -f "${backup_path}" "${bin_path}"
    else
      rm -f "${bin_path}"
    fi
    return 1
  fi

  [[ -z "${backup_path}" ]] || rm -f "${backup_path}"
}

uninstall() {
  omd_module_require_managed_uninstall "${component}" managed "$@" || return
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed Gitee CLI binary ${bin_path}; preserve configuration and authentication"
    return 0
  fi

  rm -f "${bin_path}"
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
