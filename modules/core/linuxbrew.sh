#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="linuxbrew"
brew_prefix="${HOME}/.linuxbrew"
ruby_metadata="Library/Homebrew/vendor/portable-ruby-x86_64-linux"

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

portable_ruby_sha() {
  git -C "${brew_prefix}" show "${1}:${ruby_metadata}" 2>/dev/null |
    sed -n 's/^ruby_SHA=\([[:xdigit:]]\{64\}\)$/\1/p'
}

mirror_has_ruby() {
  local checksum="$1" mirror
  [[ "${checksum}" =~ ^[[:xdigit:]]{64}$ ]] || return 1
  mirror="${HOMEBREW_ARTIFACT_DOMAIN:-https://mirrors.ustc.edu.cn/homebrew-bottles}"
  curl -fsIL --connect-timeout 8 --max-time 15 --retry 2 \
    "${mirror%/}/v2/homebrew/core/portable-ruby/blobs/sha256:${checksum}" >/dev/null 2>&1
}

select_mirrored_revision() {
  local revision checksum previous_checksum=""
  while IFS= read -r revision; do
    checksum="$(portable_ruby_sha "${revision}")" || continue
    [[ "${checksum}" != "${previous_checksum}" ]] || continue
    previous_checksum="${checksum}"
    if mirror_has_ruby "${checksum}"; then
      if [[ "${revision}" != HEAD ]]; then
        omd_module_info notice "using an earlier Linuxbrew revision while its newest portable Ruby reaches the mirror"
        git -C "${brew_prefix}" checkout --quiet --detach "${revision}" || return
      fi
      return 0
    fi
  done < <(
    printf 'HEAD\n'
    git -C "${brew_prefix}" log -4 --first-parent --format='%H' -- "${ruby_metadata}" |
      sed 's/$/^/'
  )
  omd_module_info error "the Linuxbrew mirror lacks portable Ruby for the available revisions"
  return 1
}

update_personal_brew() {
  if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" != cn ]]; then
    omd_module_brew_exec "${brew_prefix}/bin/brew" update
    return
  fi

  local installed checksum
  installed="$(git -C "${brew_prefix}" rev-parse HEAD)" || return
  git -C "${brew_prefix}" fetch --quiet --depth 1 origin HEAD </dev/null || return
  checksum="$(portable_ruby_sha FETCH_HEAD)" || return
  if ! mirror_has_ruby "${checksum}"; then
    omd_module_info notice "keeping the installed Linuxbrew until the mirror has its updated portable Ruby"
    return 0
  fi
  if omd_module_brew_exec "${brew_prefix}/bin/brew" update; then
    return 0
  fi
  git -C "${brew_prefix}" reset --keep "${installed}" || return
  return 1
}

install_or_update() {
  local action="$1" brew_remote depth=1
  shift
  omd_module_reject_unknown_flags "$@" || return

  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" == "cn" ]]; then
    brew_remote="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.ustc.edu.cn/brew.git}"
    depth=128
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
      update_personal_brew || return
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
    if git clone --depth "${depth}" "${brew_remote}" "${brew_prefix}" </dev/null && status; then
      if [[ "${depth}" != 1 ]] && ! select_mirrored_revision; then
        rm -rf -- "${brew_prefix}"
        return 1
      fi
      omd_module_mark_managed "${component}" directory "${brew_prefix}" && activate_personal_brew
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
