#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="linuxbrew"
brew_prefix="${HOME}/.linuxbrew"

status() {
  omd_module_brew_cmd >/dev/null
}

managed() {
  omd_module_marker_matches "${component}" "${brew_prefix}"
}

activate_personal_brew() {
  local profile bash_profile="${HOME}/.profile" activation
  for profile in "${HOME}/.bash_profile" "${HOME}/.bash_login"; do
    if [[ -e "${profile}" || -L "${profile}" ]]; then
      bash_profile="${profile}"
      break
    fi
  done
  activation='case ":$PATH:" in *":$HOME/.linuxbrew/bin:"*) ;; *) export PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH" ;; esac # oh-my-devpod Linuxbrew'
  for profile in "${bash_profile}" "${HOME}/.bashrc" "${HOME}/.zprofile"; do
    if [[ -L "${profile}" || ( -e "${profile}" && ( ! -f "${profile}" || ! -O "${profile}" ) ) ]]; then
      omd_module_info notice "skipping shell activation in ${profile}; add ${brew_prefix}/bin to PATH there"
    elif ! grep -Fqx -- "${activation}" "${profile}" 2>/dev/null; then
      printf '\n%s\n' "${activation}" >> "${profile}" || return 1
    fi
  done
}

install_or_update() {
  local action="$1" brew_remote
  shift
  omd_module_reject_unknown_flags "$@" || return

  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" == "cn" ]]; then
    brew_remote="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.ustc.edu.cn/brew.git}"
  else
    brew_remote="${HOMEBREW_BREW_GIT_REMOTE:-https://github.com/Homebrew/brew.git}"
  fi
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} personal Linuxbrew from ${brew_remote} under ${brew_prefix}"
    return 0
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    omd_module_info error "run Linuxbrew installation from your own account, without sudo"
    return 1
  fi
  if managed && status; then
    if [[ "${action}" == "update" ]]; then
      omd_module_brew_exec "${brew_prefix}/bin/brew" update || return
    fi
    activate_personal_brew
    return
  fi
  if omd_module_path_exists "${brew_prefix}"; then
    omd_module_info error "refusing to overwrite the existing Linuxbrew directory: ${brew_prefix}"
    return 1
  fi

  local dependency attempt
  for dependency in gcc g++ make ps curl file git; do
    omd_module_require_command "${dependency}" || return
  done
  for attempt in 1 2 3; do
    mkdir -m 0700 -- "${brew_prefix}" || return
    if git clone --depth 1 "${brew_remote}" "${brew_prefix}" && status; then
      omd_module_mark_managed "${component}" directory "${brew_prefix}" &&
        activate_personal_brew
      return
    fi
    rm -rf -- "${brew_prefix}"
    if [[ "${attempt}" -lt 3 ]]; then
      omd_module_info notice "retrying Linuxbrew download"
    fi
  done
  omd_module_info error "Linuxbrew installation did not create ${brew_prefix}/bin/brew"
  return 1
}

case "${1:-}" in
  status) status ;;
  managed) managed ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; omd_module_reject_unknown_flags "$@" && omd_module_required_uninstall "${component}" ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
