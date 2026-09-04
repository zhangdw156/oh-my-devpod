#!/usr/bin/env bash
# Shared helpers for oh-my-devpod component modules.

# shellcheck source=shared-linuxbrew.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared-linuxbrew.sh"

omd_module_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." && pwd
}

omd_module_bin_dir() {
  printf '%s\n' "${OHMYDEVPOD_BIN_DIR:-${HOME}/.local/bin}"
}

omd_module_prefix() {
  printf '%s\n' "${OHMYDEVPOD_PREFIX:-${HOME}/.local/share/oh-my-devpod}"
}

omd_module_state_dir() {
  printf '%s\n' "${OHMYDEVPOD_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/oh-my-devpod}"
}

omd_module_managed_dir() {
  printf '%s\n' "${OHMYDEVPOD_MANAGED_DIR:-$(omd_module_state_dir)/managed}"
}

omd_module_marker_path() {
  local component="$1"
  [[ "${component}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
    omd_module_info error "invalid component identifier: ${component}"
    return 2
  }
  printf '%s/%s\n' "$(omd_module_managed_dir)" "${component}"
}

omd_module_is_managed() {
  local component="$1" marker
  if [[ "${component}" == "linuxbrew" ]] && omd_shared_linuxbrew_state_claim_present; then
    omd_shared_linuxbrew_managed && omd_shared_linuxbrew_current_user_enrolled
    return
  fi
  marker="$(omd_module_marker_path "${component}")" || return
  [[ -f "${marker}" ]] && grep -qx 'managed_by=oh-my-devpod' "${marker}"
}

omd_module_mark_managed() {
  local component="$1" kind="${2:-component}" artifact="${3:-}" marker marker_dir tmp
  shift 3 || true
  marker="$(omd_module_marker_path "${component}")" || return
  marker_dir="$(dirname "${marker}")"
  mkdir -p "${marker_dir}"
  tmp="${marker}.tmp.$$"
  {
    printf 'managed_by=oh-my-devpod\n'
    printf 'component=%s\n' "${component}"
    printf 'kind=%s\n' "${kind}"
    printf 'artifact=%s\n' "${artifact}"
    printf 'installed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if (($#)); then
      printf '%s\n' "$@"
    fi
  } > "${tmp}"
  mv "${tmp}" "${marker}"
}

omd_module_marker_value() {
  local component="$1" key="$2" marker
  if [[ "${component}" == "linuxbrew" ]] && omd_shared_linuxbrew_state_claim_present; then
    omd_shared_linuxbrew_managed && omd_shared_linuxbrew_current_user_enrolled || return 1
    case "${key}" in
      artifact) omd_shared_linuxbrew_prefix ;;
      kind) printf 'directory\n' ;;
      *) omd_shared_linuxbrew_manifest_value "${key}" ;;
    esac
    return
  fi
  marker="$(omd_module_marker_path "${component}")" || return
  [[ -f "${marker}" ]] || return 1
  sed -n "s/^${key}=//p" "${marker}" | head -n 1
}

omd_module_marker_matches() {
  local component="$1" artifact="$2" recorded
  omd_module_is_managed "${component}" || return 1
  recorded="$(omd_module_marker_value "${component}" artifact)" || return 1
  [[ "${recorded}" == "${artifact}" ]]
}

omd_module_unmark_managed() {
  local component="$1" marker
  marker="$(omd_module_marker_path "${component}")" || return
  rm -f "${marker}"
}

omd_module_info() {
  local level="$1" message="$2"
  printf '%s: %s\n' "${level}" "${message}"
}

omd_module_has_flag() {
  local needle="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "${needle}" ]] && return 0
  done
  return 1
}

omd_module_dry_run() {
  omd_module_has_flag --dry-run "$@"
}

omd_module_reject_unknown_flags() {
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "--dry-run" ]] || {
      omd_module_info error "unknown option: ${arg}"
      return 2
    }
  done
}

omd_module_required_uninstall() {
  local name="$1"
  omd_module_info error "${name} cannot be removed by the normal uninstall flow"
  return 2
}

omd_module_refuse_unmanaged() {
  local name="$1"
  omd_module_info error "${name} is not managed by oh-my-devpod; refusing to remove it"
  return 1
}

omd_module_unknown_action() {
  local action="${1:-}"
  omd_module_info error "unknown action: ${action:-<empty>}"
  return 2
}

omd_module_require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    omd_module_info error "missing required command: ${cmd}"
    return 1
  fi
}

omd_module_sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${path}" | awk '{print $1}'
  else
    omd_module_info error "sha256sum or shasum is required"
    return 1
  fi
}

omd_module_path_exists() {
  local path="$1"
  [[ -e "${path}" || -L "${path}" ]]
}

omd_module_remove_tree() {
  local path="$1"
  case "${path}" in
    ""|/|"${HOME}")
      omd_module_info error "refusing unsafe recursive removal path: ${path:-<empty>}"
      return 2
      ;;
  esac
  [[ "${path}" == /* ]] || {
    omd_module_info error "refusing non-absolute recursive removal path: ${path}"
    return 2
  }
  rm -rf -- "${path}"
}

omd_module_brew_cmd() {
  local candidate
  if [[ -n "${OHMYDEVPOD_BREW_BIN:-}" && -x "${OHMYDEVPOD_BREW_BIN}" ]]; then
    printf '%s\n' "${OHMYDEVPOD_BREW_BIN}"
    return 0
  fi
  if omd_shared_linuxbrew_managed; then
    candidate="$(omd_shared_linuxbrew_gateway)"
    [[ -x "${candidate}" ]] || return 1
    printf '%s\n' "${candidate}"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi
  for candidate in \
    "${HOMEBREW_PREFIX:-}/bin/brew" \
    /home/linuxbrew/.linuxbrew/bin/brew \
    "${HOME}/.linuxbrew/bin/brew"; do
    [[ "${candidate}" == "/bin/brew" ]] && continue
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

omd_module_brew_formula_installed_at() {
  local prefix="$1" formula="$2" formula_name cellar version
  formula_name="${formula##*/}"
  cellar="${prefix}/Cellar/${formula_name}"
  [[ -d "${cellar}" ]] || return 1
  for version in "${cellar}"/*; do
    [[ -e "${version}" ]] && return 0
  done
  return 1
}

omd_module_brew_formula_installed() {
  local formula="$1" prefix
  prefix="$(omd_module_brew_prefix)" || return 1
  omd_module_brew_formula_installed_at "${prefix}" "${formula}"
}

omd_module_brew_prefix_for_cmd() {
  local brew="$1" prefix
  prefix="$(omd_module_brew_exec "${brew}" --prefix 2>/dev/null || true)"
  if [[ "${prefix}" == /* && -d "${prefix}" ]]; then
    cd "${prefix}" 2>/dev/null && pwd -P
    return
  fi
  [[ "${brew}" == */bin/brew ]] || return 1
  cd "$(dirname "${brew}")/.." 2>/dev/null && pwd -P
}

omd_module_brew_cmd_matches_prefix() {
  local brew="$1" expected_prefix="$2" resolved_brew reported_prefix
  expected_prefix="$(cd "${expected_prefix}" 2>/dev/null && pwd -P)" || return 1
  if [[ -L "${brew}" ]]; then
    command -v readlink >/dev/null 2>&1 || return 1
    resolved_brew="$(readlink -f "${brew}" 2>/dev/null || true)"
    [[ "${resolved_brew}" == "${expected_prefix}"/* ]] || return 1
  fi
  reported_prefix="$(omd_module_brew_prefix_for_cmd "${brew}")" || return 1
  [[ "${reported_prefix}" == "${expected_prefix}" ]]
}

omd_module_brew_prefix() {
  local brew
  brew="$(omd_module_brew_cmd)" || return 1
  if omd_module_brew_prefix_for_cmd "${brew}"; then
    return 0
  fi
  if [[ -n "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX}" ]]; then
    printf '%s\n' "${HOMEBREW_PREFIX}"
    return 0
  fi
  return 1
}

omd_module_brew_exec() {
  local brew="$1"
  shift
  env -u HOMEBREW_ASK \
    OHMYDEVPOD_BREW_NONINTERACTIVE=1 \
    NONINTERACTIVE=1 \
    HOMEBREW_NO_ASK=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    "${brew}" "$@"
}

omd_module_formula_status() {
  local formula="$1" command_name="$2" prefix
  if [[ -n "${component:-}" ]] && omd_module_formula_managed "${component}" "${formula}"; then
    prefix="$(omd_module_formula_marker_prefix "${component}" "${formula}")" || return 1
    omd_module_brew_formula_installed_at "${prefix}" "${formula}"
    return
  fi
  command -v "${command_name}" >/dev/null 2>&1 ||
    omd_module_brew_formula_installed "${formula}"
}

omd_module_formula_managed() {
  local component="$1" formula="$2" kind
  if omd_shared_linuxbrew_state_claim_present; then
    omd_shared_linuxbrew_formula_managed "${component}" "${formula}"
    return
  fi
  omd_module_marker_matches "${component}" "${formula}" || return 1
  kind="$(omd_module_marker_value "${component}" kind || true)"
  [[ "${kind}" == "brew-formula" ]]
}

omd_module_formula_marker_prefix() {
  local component="$1" formula="$2" prefix linuxbrew_kind
  if omd_shared_linuxbrew_state_claim_present; then
    omd_shared_linuxbrew_formula_prefix "${component}" "${formula}"
    return
  fi
  omd_module_formula_managed "${component}" "${formula}" || return 1
  prefix="$(omd_module_marker_value "${component}" brew_prefix || true)"
  if [[ -z "${prefix}" ]] && omd_module_is_managed linuxbrew; then
    linuxbrew_kind="$(omd_module_marker_value linuxbrew kind || true)"
    if [[ "${linuxbrew_kind}" == "directory" ]]; then
      prefix="$(omd_module_marker_value linuxbrew artifact || true)"
      if ! omd_module_brew_formula_installed_at "${prefix}" "${formula}"; then
        prefix=""
      fi
    fi
  fi
  [[ -n "${prefix}" && "${prefix}" == /* && ! -L "${prefix}" && -x "${prefix}/bin/brew" ]] ||
    return 1
  prefix="$(cd "${prefix}" 2>/dev/null && pwd -P)" || return 1
  omd_module_brew_cmd_matches_prefix "${prefix}/bin/brew" "${prefix}" || return 1
  printf '%s\n' "${prefix}"
}

omd_module_formula_brew_cmd() {
  local component="$1" formula="$2" prefix
  if omd_shared_linuxbrew_formula_managed "${component}" "${formula}"; then
    omd_shared_linuxbrew_gateway
    return
  fi
  prefix="$(omd_module_formula_marker_prefix "${component}" "${formula}")" || return 1
  printf '%s/bin/brew\n' "${prefix}"
}

omd_module_formula_install_or_update() {
  local component="$1" formula="$2" command_name="$3" action="$4" brew brew_prefix
  shift 4
  omd_module_reject_unknown_flags "$@" || return

  if omd_module_formula_status "${formula}" "${command_name}" &&
    ! omd_module_formula_managed "${component}" "${formula}"; then
    omd_module_info notice "preserving external ${component} installation"
    return 0
  fi

  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} host-shared Homebrew formula ${formula}"
    return 0
  fi

  if omd_module_formula_managed "${component}" "${formula}"; then
    brew="$(omd_module_formula_brew_cmd "${component}" "${formula}")" || {
      omd_module_info error "managed ${component} has no valid owning Homebrew prefix"
      return 1
    }
  else
    brew="$(omd_module_brew_cmd)" || {
      omd_module_info error "Linuxbrew is required before ${component}"
      return 1
    }
  fi
  brew_prefix="$(omd_module_brew_prefix_for_cmd "${brew}")" || {
    omd_module_info error "could not determine Homebrew prefix for ${component}"
    return 1
  }

  if [[ "${action}" == "update" ]] &&
    omd_module_brew_formula_installed_at "${brew_prefix}" "${formula}"; then
    omd_module_brew_exec "${brew}" upgrade "${formula}"
  else
    omd_module_brew_exec "${brew}" install "${formula}"
  fi
  if omd_shared_linuxbrew_managed; then
    omd_shared_linuxbrew_formula_managed "${component}" "${formula}" || {
      omd_module_info error "shared Brew inventory did not record ${formula}"
      return 1
    }
  else
    omd_module_mark_managed \
      "${component}" \
      brew-formula \
      "${formula}" \
      "brew_prefix=${brew_prefix}"
  fi
}

omd_module_formula_uninstall_impl() {
  local component="$1" formula="$2" remove_marker="$3"
  shift 3
  omd_module_reject_unknown_flags "$@" || return

  if omd_module_dry_run "$@"; then
    omd_module_info plan "uninstall host-shared Homebrew formula ${formula} for all users"
    return 0
  fi

  omd_module_formula_managed "${component}" "${formula}" ||
    omd_module_refuse_unmanaged "${component}" || return

  local brew brew_prefix dependants
  brew="$(omd_module_formula_brew_cmd "${component}" "${formula}")" || {
    omd_module_info error "managed ${component} has no valid owning Homebrew prefix"
    return 1
  }
  brew_prefix="$(omd_module_brew_prefix_for_cmd "${brew}")" || return 1
  if ! omd_module_brew_formula_installed_at "${brew_prefix}" "${formula}"; then
    if [[ "${remove_marker}" == "1" ]]; then
      omd_module_unmark_managed "${component}"
    fi
    return 0
  fi
  if ! dependants="$(omd_module_brew_exec "${brew}" uses --installed "${formula}" 2>&1)"; then
    omd_module_info error "failed to inspect Homebrew dependants for ${component}: ${dependants}"
    return 1
  fi
  if [[ -n "${dependants}" ]]; then
    omd_module_info error "cannot uninstall ${component}; Homebrew dependants remain: ${dependants//$'\n'/, }"
    return 1
  fi
  omd_module_brew_exec "${brew}" uninstall "${formula}"
  if [[ "${remove_marker}" == "1" ]] && ! omd_shared_linuxbrew_managed; then
    omd_module_unmark_managed "${component}"
  fi
}

omd_module_formula_uninstall() {
  local component="$1" formula="$2"
  shift 2
  omd_module_formula_uninstall_impl "${component}" "${formula}" 1 "$@"
}

omd_module_formula_uninstall_keep_marker() {
  local component="$1" formula="$2"
  shift 2
  omd_module_formula_uninstall_impl "${component}" "${formula}" 0 "$@"
}

omd_module_zsh_path() {
  local brew prefix candidate
  if brew="$(omd_module_brew_cmd)"; then
    prefix="$(omd_module_brew_exec "${brew}" --prefix zsh 2>/dev/null || true)"
    candidate="${prefix}/bin/zsh"
    if [[ -n "${prefix}" && -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi
  command -v zsh
}

omd_module_target_user() {
  if [[ -n "${OHMYDEVPOD_TARGET_USER:-}" ]]; then
    printf '%s\n' "${OHMYDEVPOD_TARGET_USER}"
  elif [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    printf '%s\n' "${SUDO_USER}"
  else
    id -un
  fi
}

omd_module_set_login_shell() {
  local zsh_path="$1" target_user current_shell shells_file sudo_bin
  [[ -x "${zsh_path}" ]] || {
    omd_module_info error "cannot set login shell; Zsh is not executable: ${zsh_path}"
    return 1
  }

  target_user="$(omd_module_target_user)"
  shells_file="${OHMYDEVPOD_SHELLS_FILE:-/etc/shells}"
  sudo_bin="${OHMYDEVPOD_SUDO_BIN:-sudo}"
  if [[ -n "${OHMYDEVPOD_CURRENT_SHELL:-}" ]]; then
    current_shell="${OHMYDEVPOD_CURRENT_SHELL}"
  elif command -v getent >/dev/null 2>&1; then
    current_shell="$(getent passwd "${target_user}" 2>/dev/null | awk -F: '{print $7}')"
  else
    current_shell="${SHELL:-}"
  fi

  if ! grep -Fqx "${zsh_path}" "${shells_file}" 2>/dev/null; then
    if [[ "$(id -u)" -eq 0 ]]; then
      printf '%s\n' "${zsh_path}" >> "${shells_file}"
    else
      omd_module_require_command "${sudo_bin}"
      printf '%s\n' "${zsh_path}" | "${sudo_bin}" tee -a "${shells_file}" >/dev/null
    fi
  fi

  if [[ "${current_shell}" != "${zsh_path}" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      chsh -s "${zsh_path}" "${target_user}"
    else
      omd_module_require_command "${sudo_bin}"
      "${sudo_bin}" chsh -s "${zsh_path}" "${target_user}"
    fi
    omd_module_info notice "login shell for ${target_user} set to ${zsh_path}; it takes effect on next login"
  fi
}

omd_module_external_installation() {
  local component="$1"
  omd_module_info notice "preserving external ${component} installation"
}

omd_module_require_managed_uninstall() {
  local component="$1" managed_function="$2"
  shift 2
  omd_module_reject_unknown_flags "$@" || return
  omd_module_dry_run "$@" && return 0
  "${managed_function}" ||
    omd_module_refuse_unmanaged "${component}" || return
}
