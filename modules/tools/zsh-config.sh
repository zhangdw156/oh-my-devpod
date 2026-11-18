#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

component="zsh-config"
repo_root="$(omd_module_repo_root)"
zsh_dir="${OHMYDEVPOD_ZSH_DIR:-$(omd_module_prefix)/zsh}"
zshrc="${OHMYDEVPOD_ZSHRC:-${HOME}/.zshrc}"
p10k="${OHMYDEVPOD_P10K_CONFIG:-${HOME}/.p10k.zsh}"
managed_header="# oh-my-devpod managed zsh config"
zshenv="${zshrc%/*}/.zshenv"
# Ubuntu's global zshrc reads this opt-out before the managed .zshrc runs.
zshenv_line='if [[ -o interactive ]]; then skip_global_compinit=1; fi # oh-my-devpod: completion is initialized in .zshrc'

status() {
  [[ -f "${zshrc}" ]] && grep -Fqx "${managed_header}" "${zshrc}"
}

managed() {
  omd_module_marker_matches "${component}" "${zshrc}"
}

backup_existing_config() {
  local backup_dir="$1"
  mkdir -p "${backup_dir}"
  [[ ! -e "${zshrc}" ]] || mv "${zshrc}" "${backup_dir}/zshrc"
  [[ ! -e "${p10k}" ]] || mv "${p10k}" "${backup_dir}/p10k.zsh"
}

preserve_modified_file() {
  local path="$1" label="$2" expected actual destination
  [[ -f "${path}" ]] || return 0
  expected="$(omd_module_marker_value "${component}" "${label}_sha256" || true)"
  [[ -n "${expected}" ]] || return 0
  actual="$(omd_module_sha256_file "${path}")"
  [[ "${actual}" == "${expected}" ]] && return 0

  destination="$(omd_module_state_dir)/backups/${component}/modified-$(date -u +%Y%m%d%H%M%SZ)-${label}"
  mkdir -p "$(dirname "${destination}")"
  cp "${path}" "${destination}"
  omd_module_info notice "preserved modified ${path} at ${destination}"
}

startup_file_is_editable() {
  [[ ! -L "$1" && ( ! -e "$1" || ( -f "$1" && -O "$1" && -w "$1" ) ) ]]
}

# Apply a single recognizable line, preserving the rest of the user's startup file.
edit_startup_line() (
  local action="$1" path="$2" line="$3" position="$4" original="$5" temporary line_number
  local LC_ALL=C
  if ! startup_file_is_editable "${path}"; then
    omd_module_info notice "leaving ${path} untouched${6:-}"
    return 0
  fi
  if [[ ! -e "${path}" ]]; then
    [[ "${action}" != uninstall ]] || return 0
    (umask 077; set -C; printf '%s\n' "${line}" > "${path}")
    return
  fi
  line_number="$(grep -nm1 -Fx -- "${line}" "${path}" | cut -d: -f1)" || line_number=""
  if [[ "${action}" == uninstall && -z "${line_number}" ]] ||
     [[ "${action}" != uninstall && -n "${line_number}" ]]; then
    return 0
  fi
  if [[ "${action}" == uninstall && "${original}" == created ]] &&
     cmp -s "${path}" <(printf '%s\n' "${line}"); then
    rm -- "${path}"
    return
  fi
  temporary="$(mktemp "${path}.XXXXXXXX")" || return
  trap 'rm -f -- "${temporary}"' EXIT
  cp -p -- "${path}" "${temporary}" || return
  if [[ "${action}" == uninstall ]]; then
    if [[ "${original}" == unterminated && "${line_number}" != 1 && "$(tail -n1 "${path}")" == "${line}" ]] &&
       [[ -z "$(tail -c1 "${path}")" ]]; then
      # Drop the newline we inserted between the user's last byte and our hook.
      head -c "$(( $(wc -c < "${path}") - ${#line} - 2 ))" "${path}" > "${temporary}" || return
    else
      sed "${line_number}d" "${path}" > "${temporary}" || return
    fi
  elif [[ "${position}" == first ]]; then
    printf '%s\n' "${line}" > "${temporary}" || return
    cat "${path}" >> "${temporary}" || return
  else
    if [[ -n "$(tail -c1 "${path}")" ]]; then
      printf '\n' >> "${temporary}" || return
    fi
    printf '%s\n' "${line}" >> "${temporary}" || return
  fi
  mv -- "${temporary}" "${path}"
)

configure_zshenv() {
  local original=existing
  [[ "${zshrc##*/}" == .zshrc ]] || return 0
  [[ "$2" != 1 ]] || original=created
  edit_startup_line "$1" "${zshenv}" "${zshenv_line}" first "${original}" \
    '; Ubuntu users can set skip_global_compinit=1 there if global compinit prompts'
}

configure_ssh_login() {
  local action="$1" previous original name hook_line
  printf -v hook_line 'if [ -n "${BASH_VERSION:-}" ] && [ -n "${SSH_TTY:-}" ] && [ -r %q ]; then . %q; fi # oh-my-devpod SSH login' \
    "${zsh_dir}/ssh-login.bash" "${zsh_dir}/ssh-login.bash"
  previous="$(omd_module_marker_value "${component}" login_profile || true)"
  original="$(omd_module_marker_value "${component}" login_profile_original || true)"
  login_profile=""
  login_profile_original=""
  if [[ "${action}" != uninstall && "${zshrc}" == "${HOME}/.zshrc" && -x "${HOME}/.linuxbrew/bin/zsh" ]] &&
     omd_module_formula_managed zsh zsh; then
    for name in .bash_profile .bash_login .profile; do
      if [[ -r "${HOME}/${name}" || "${name}" == .profile ]]; then
        if startup_file_is_editable "${HOME}/${name}"; then
          login_profile="${name}"
        else
          omd_module_info notice "leaving ${HOME}/${name} untouched"
        fi
        break
      fi
    done
  fi
  case "${previous}" in
    .bash_profile|.bash_login|.profile)
      if [[ "${previous}" != "${login_profile}" ]]; then
        edit_startup_line uninstall "${HOME}/${previous}" "${hook_line}" last "${original}"
      fi
      ;;
  esac
  [[ -n "${login_profile}" ]] || return 0
  if [[ "${login_profile}" == "${previous}" ]]; then
    login_profile_original="${original}"
    # A user may comment out or remove their SSH opt-in between OMD updates.
    return 0
  elif [[ ! -e "${HOME}/${login_profile}" ]]; then
    login_profile_original=created
  elif [[ -f "${HOME}/${login_profile}" && -n "$(tail -c1 "${HOME}/${login_profile}")" ]]; then
    login_profile_original=unterminated
  fi
  edit_startup_line "${action}" "${HOME}/${login_profile}" "${hook_line}" last "${login_profile_original}"
}

write_zshrc() {
  local source_file="${repo_root}/config/.zshrc" source_config_dir line
  source_config_dir="${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/oh-my-devpod}"
  {
    printf '%s\n' "${managed_header}"
    printf 'export OHMYDEVPOD_CONFIG_DIR=%q\n' "${source_config_dir}"
    cat <<'EOF'
if [[ -f "${OHMYDEVPOD_CONFIG_DIR}/env" ]]; then
  set -a
  source "${OHMYDEVPOD_CONFIG_DIR}/env"
  set +a
fi
if [[ -x "$HOME/.linuxbrew/bin/brew" && ! -L "$HOME/.linuxbrew" ]]; then
  export PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"
EOF
    while IFS= read -r line || [[ -n "${line}" ]]; do
      printf '%s\n' "${line//\/opt\/vendor\/zsh/${zsh_dir}}"
    done < "${source_file}"
  } > "${zshrc}"
}

install_or_update() {
  local action="$1" backup_dir="" backup_parent created_zshenv=0 login_profile login_profile_original
  shift
  omd_module_reject_unknown_flags "$@" || return
  if status && ! managed; then
    omd_module_external_installation "${component}"
    return 0
  fi
  if omd_module_path_exists "${zsh_dir}" && ! managed; then
    omd_module_info error "refusing to overwrite unmanaged Zsh asset directory: ${zsh_dir}"
    return 1
  fi
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} managed Zsh configuration and enable interactive SSH login for the account's managed Zsh"
    return 0
  fi

  if ! managed; then
    backup_parent="$(omd_module_state_dir)/backups/${component}"
    mkdir -p "${backup_parent}"
    backup_dir="$(mktemp -d "${backup_parent}/backup.XXXXXXXX")"
    backup_existing_config "${backup_dir}"
  else
    backup_dir="$(omd_module_marker_value "${component}" backup_dir || true)"
    preserve_modified_file "${zshrc}" zshrc
    preserve_modified_file "${p10k}" p10k
  fi

  omd_module_remove_tree "${zsh_dir}"
  mkdir -p "${zsh_dir}" "$(dirname "${zshrc}")" "$(dirname "${p10k}")"
  cp -R "${repo_root}/vendor/zsh/." "${zsh_dir}/"
  OHMYDEVPOD_ASSET_ROOT="${OHMYDEVPOD_ASSET_ROOT:-${repo_root}/vendor/releases}" \
    OHMYDEVPOD_ANTIDOTE_DIR="${zsh_dir}/antidote" \
    bash "${repo_root}/build/install-antidote.sh"
  cp "${repo_root}/config/.p10k.zsh" "${p10k}"
  write_zshrc
  if [[ ! -e "${zshenv}" && ! -L "${zshenv}" ]]; then
    created_zshenv=1
  else
    created_zshenv="$(omd_module_marker_value "${component}" created_zshenv || true)"
  fi
  configure_zshenv "${action}" "${created_zshenv}"
  cp "${repo_root}/config/ssh-login.bash" "${zsh_dir}/ssh-login.bash"
  configure_ssh_login "${action}"
  omd_module_mark_managed \
    "${component}" \
    configuration \
    "${zshrc}" \
    "backup_dir=${backup_dir}" \
    "login_profile=${login_profile}" \
    "login_profile_original=${login_profile_original}" \
    "created_zshenv=${created_zshenv:-0}" \
    "zshrc_sha256=$(omd_module_sha256_file "${zshrc}")" \
    "p10k_sha256=$(omd_module_sha256_file "${p10k}")"
  if [[ -x "${HOME}/.linuxbrew/bin/zsh" ]]; then
    omd_module_info notice 'To use Zsh in this terminal, run: exec "$HOME/.linuxbrew/bin/zsh" -l'
  fi
}

uninstall() {
  local backup_dir login_profile login_profile_original
  omd_module_require_managed_uninstall "${component}" managed "$@" || return
  if omd_module_dry_run "$@"; then
    omd_module_info plan "remove managed Zsh configuration and restore preserved files when available"
    return 0
  fi
  status || {
    omd_module_info error "managed Zsh header is missing; refusing to remove ${zshrc}"
    return 1
  }
  backup_dir="$(omd_module_marker_value "${component}" backup_dir || true)"
  preserve_modified_file "${zshrc}" zshrc
  preserve_modified_file "${p10k}" p10k

  configure_ssh_login uninstall
  configure_zshenv uninstall "$(omd_module_marker_value "${component}" created_zshenv || true)"
  rm -f "${zshrc}" "${p10k}"
  rm -rf "${zsh_dir}"
  if [[ -n "${backup_dir}" ]]; then
    [[ ! -e "${backup_dir}/zshrc" ]] || mv "${backup_dir}/zshrc" "${zshrc}"
    [[ ! -e "${backup_dir}/p10k.zsh" ]] || mv "${backup_dir}/p10k.zsh" "${p10k}"
    rmdir "${backup_dir}" 2>/dev/null || true
  fi
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
