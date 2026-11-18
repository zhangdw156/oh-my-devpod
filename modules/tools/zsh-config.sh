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

configure_zshenv() (
  local action="$1" created="$2" temporary line_number
  [[ "${zshrc##*/}" == .zshrc ]] || return 0
  if [[ -L "${zshenv}" || ( -e "${zshenv}" && ( ! -f "${zshenv}" || ! -O "${zshenv}" ) ) ]]; then
    omd_module_info notice "leaving ${zshenv} untouched; Ubuntu users can set skip_global_compinit=1 there if global compinit prompts"
    return 0
  fi
  if [[ ! -e "${zshenv}" ]]; then
    [[ "${action}" != uninstall ]] || return 0
    (umask 077; set -C; printf '%s\n' "${zshenv_line}" > "${zshenv}")
    return
  fi
  line_number="$(grep -nm1 -Fx -- "${zshenv_line}" "${zshenv}" | cut -d: -f1)" || line_number=""
  if [[ "${action}" == uninstall && -z "${line_number}" ]] ||
     [[ "${action}" != uninstall && -n "${line_number}" ]]; then
    return 0
  fi
  if [[ "${action}" == uninstall && "${created}" == 1 ]] &&
     cmp -s "${zshenv}" <(printf '%s\n' "${zshenv_line}"); then
    rm -- "${zshenv}"
    return
  fi
  temporary="$(mktemp "${zshenv}.XXXXXXXX")" || return
  trap 'rm -f -- "${temporary}"' EXIT
  cp -p -- "${zshenv}" "${temporary}" || return
  if [[ "${action}" == uninstall ]]; then
    sed "${line_number}d" "${zshenv}" > "${temporary}" || return
  else
    printf '%s\n' "${zshenv_line}" > "${temporary}" || return
    cat "${zshenv}" >> "${temporary}" || return
  fi
  mv -- "${temporary}" "${zshenv}"
)

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
  local action="$1" backup_dir="" backup_parent created_zshenv=0
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
    omd_module_info plan "${action} managed Zsh assets, ~/.zshrc, and Powerlevel10k"
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
  omd_module_mark_managed \
    "${component}" \
    configuration \
    "${zshrc}" \
    "backup_dir=${backup_dir}" \
    "created_zshenv=${created_zshenv:-0}" \
    "zshrc_sha256=$(omd_module_sha256_file "${zshrc}")" \
    "p10k_sha256=$(omd_module_sha256_file "${p10k}")"
}

uninstall() {
  local backup_dir
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
