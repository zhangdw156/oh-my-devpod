#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="linuxbrew"
brew_prefix="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"

status() {
  if managed; then
    [[ -x "${brew_prefix}/bin/brew" ]]
    return
  fi
  [[ -x "${brew_prefix}/bin/brew" ]] || command -v brew >/dev/null 2>&1
}

managed() {
  omd_module_marker_matches "${component}" "${brew_prefix}"
}

install_or_update() {
  local action="$1" brew_remote
  shift
  omd_module_reject_unknown_flags "$@" || return

  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if omd_module_dry_run "$@"; then
    if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" == "cn" ]]; then
      brew_remote="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.ustc.edu.cn/brew.git}"
      omd_module_info plan "${action} Linuxbrew from ${brew_remote} under ${brew_prefix}"
    else
      omd_module_info plan "${action} Linuxbrew under ${brew_prefix}"
    fi
    return 0
  fi

  if managed && [[ -x "${brew_prefix}/bin/brew" ]]; then
    omd_module_brew_exec "${brew_prefix}/bin/brew" update
    return 0
  fi

  if managed; then
    omd_module_info notice "repairing damaged managed Linuxbrew prefix: ${brew_prefix}"
    omd_module_remove_tree "${brew_prefix}"
  elif [[ -d "${brew_prefix}" ]] && [[ -n "$(find "${brew_prefix}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    omd_module_info error "refusing to overwrite non-empty unmanaged prefix: ${brew_prefix}"
    return 1
  fi

  if command -v apt-get >/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]]; then
      apt-get update
      apt-get install -y build-essential procps curl file git ca-certificates
    else
      omd_module_require_command sudo
      sudo apt-get update
      sudo apt-get install -y build-essential procps curl file git ca-certificates
    fi
  fi

  if ! mkdir -p "${brew_prefix}" 2>/dev/null; then
    if [[ "$(id -u)" -eq 0 ]]; then
      mkdir -p "${brew_prefix}"
    else
      omd_module_require_command sudo
      sudo mkdir -p "${brew_prefix}"
      sudo chown -R "$(id -u):$(id -g)" "${brew_prefix}"
    fi
  fi

  if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" == "cn" ]]; then
    brew_remote="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.ustc.edu.cn/brew.git}"
    omd_module_require_command git
    git clone --depth 1 "${brew_remote}" "${brew_prefix}"
  else
    omd_module_require_command curl
    omd_module_require_command tar
    curl -fsSL https://github.com/Homebrew/brew/tarball/master |
      tar xz --strip-components 1 -C "${brew_prefix}"
  fi
  [[ -x "${brew_prefix}/bin/brew" ]] || {
    omd_module_info error "Linuxbrew installation did not create ${brew_prefix}/bin/brew"
    return 1
  }
  omd_module_mark_managed "${component}" directory "${brew_prefix}"
}

case "${1:-}" in
  status) status ;;
  managed) managed ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; omd_module_reject_unknown_flags "$@" && omd_module_required_uninstall "${component}" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
