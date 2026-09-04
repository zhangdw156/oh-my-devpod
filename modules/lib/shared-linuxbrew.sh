#!/usr/bin/env bash
# Host-scoped Linuxbrew state shared by every OMD user.

omd_shared_linuxbrew_test_mode() {
  [[ "${OHMYDEVPOD_SHARED_BREW_TEST_MODE:-0}" == "1" ]]
}

omd_shared_linuxbrew_prefix() {
  if omd_shared_linuxbrew_test_mode; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  else
    printf '%s\n' "/home/linuxbrew/.linuxbrew"
  fi
}

omd_shared_linuxbrew_state_dir() {
  if omd_shared_linuxbrew_test_mode; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_STATE_DIR:-/var/lib/oh-my-devpod/linuxbrew}"
  else
    printf '%s\n' "/var/lib/oh-my-devpod/linuxbrew"
  fi
}

omd_shared_linuxbrew_libexec_dir() {
  if omd_shared_linuxbrew_test_mode; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR:-/usr/local/libexec/oh-my-devpod}"
  else
    printf '%s\n' "/usr/local/libexec/oh-my-devpod"
  fi
}

omd_shared_linuxbrew_gateway() {
  printf '%s/bin/brew\n' "$(omd_shared_linuxbrew_libexec_dir)"
}

omd_shared_linuxbrew_manifest() {
  printf '%s/manifest\n' "$(omd_shared_linuxbrew_state_dir)"
}

omd_shared_linuxbrew_state_claim_present() {
  local manifest
  manifest="$(omd_shared_linuxbrew_manifest)"
  [[ -e "${manifest}" || -L "${manifest}" ]]
}

omd_shared_linuxbrew_legacy_marker() {
  local prefix owner_uid owner_home=""
  prefix="$(omd_shared_linuxbrew_prefix)"
  if omd_shared_linuxbrew_test_mode; then
    owner_home="${OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME:-${HOME}}"
  else
    owner_uid="$(omd_shared_linuxbrew_stat_uid "${prefix}")" || return 1
    if command -v getent >/dev/null 2>&1; then
      owner_home="$(getent passwd "${owner_uid}" 2>/dev/null | awk -F: '{print $6}')"
    elif [[ "$(id -u)" == "${owner_uid}" ]]; then
      owner_home="${HOME}"
    fi
  fi
  [[ "${owner_home}" == /* && -d "${owner_home}" && ! -L "${owner_home}" ]] || return 1
  printf '%s/.local/state/oh-my-devpod/managed/linuxbrew\n' "${owner_home}"
}

omd_shared_linuxbrew_activation_candidate() {
  local prefix marker
  if omd_shared_linuxbrew_state_claim_present; then
    return 0
  fi
  prefix="$(omd_shared_linuxbrew_prefix)"
  [[ -e "${prefix}" || -L "${prefix}" ]] || return 1
  marker="$(omd_shared_linuxbrew_legacy_marker)"
  [[ -f "${marker}" && ! -L "${marker}" ]] || return 1
  grep -Fqx 'managed_by=oh-my-devpod' "${marker}" || return 1
  grep -Fqx 'component=linuxbrew' "${marker}" || return 1
  grep -Fqx 'kind=directory' "${marker}" || return 1
  grep -Fqx "artifact=${prefix}" "${marker}"
}

omd_shared_linuxbrew_enabled() {
  [[ "${OHMYDEVPOD_SHARED_BREW_DISABLE:-0}" != "1" ]]
}

omd_shared_linuxbrew_manifest_value() {
  local key="$1" manifest
  manifest="$(omd_shared_linuxbrew_manifest)"
  [[ -f "${manifest}" && ! -L "${manifest}" ]] || return 1
  sed -n "s/^${key}=//p" "${manifest}" | head -n 1
}

omd_shared_linuxbrew_group_gid() {
  local group="$1"
  if command -v getent >/dev/null 2>&1; then
    getent group "${group}" | awk -F: '{print $3}'
  else
    id -g "${group}"
  fi
}

omd_shared_linuxbrew_stat_uid() {
  if stat -c '%u' "$1" >/dev/null 2>&1; then stat -c '%u' "$1"; else stat -f '%u' "$1"; fi
}

omd_shared_linuxbrew_stat_gid() {
  if stat -c '%g' "$1" >/dev/null 2>&1; then stat -c '%g' "$1"; else stat -f '%g' "$1"; fi
}

omd_shared_linuxbrew_stat_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}

omd_shared_linuxbrew_validate() {
  local manifest prefix recorded_prefix resolved_prefix recorded_resolved_prefix schema
  local service_user manager_group installation_id
  local expected_uid expected_gid actual_uid actual_gid
  omd_shared_linuxbrew_enabled || return 1
  manifest="$(omd_shared_linuxbrew_manifest)"
  [[ -f "${manifest}" && ! -L "${manifest}" ]] || return 1
  schema="$(omd_shared_linuxbrew_manifest_value schema_version || true)"
  case "${schema}" in 1|2) ;; *) return 1 ;; esac
  [[ "$(omd_shared_linuxbrew_manifest_value managed_by || true)" == "oh-my-devpod" ]] || return 1
  [[ "$(omd_shared_linuxbrew_manifest_value mode || true)" == "shared-service-account" ]] || return 1

  prefix="$(omd_shared_linuxbrew_prefix)"
  recorded_prefix="$(omd_shared_linuxbrew_manifest_value prefix || true)"
  [[ "${recorded_prefix}" == "${prefix}" && "${prefix}" == /* && ! -L "${prefix}" ]] || return 1
  [[ -d "${prefix}" && -x "${prefix}/bin/brew" ]] || return 1
  resolved_prefix="$(cd "${prefix}" 2>/dev/null && pwd -P)" || return 1
  if [[ "${schema}" == "1" ]]; then
    recorded_resolved_prefix="${recorded_prefix}"
  else
    recorded_resolved_prefix="$(omd_shared_linuxbrew_manifest_value resolved_prefix || true)"
  fi
  [[ "${resolved_prefix}" == "${recorded_resolved_prefix}" ]] || return 1

  service_user="$(omd_shared_linuxbrew_manifest_value service_user || true)"
  manager_group="$(omd_shared_linuxbrew_manifest_value manager_group || true)"
  expected_uid="$(omd_shared_linuxbrew_manifest_value service_uid || true)"
  expected_gid="$(omd_shared_linuxbrew_manifest_value service_gid || true)"
  installation_id="$(omd_shared_linuxbrew_manifest_value installation_id || true)"
  [[ "${service_user}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || return 1
  [[ "${manager_group}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || return 1
  [[ "${expected_uid}" =~ ^[0-9]+$ && "${expected_gid}" =~ ^[0-9]+$ ]] || return 1
  [[ "${installation_id}" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || return 1
  actual_uid="$(id -u "${service_user}" 2>/dev/null || true)"
  if omd_shared_linuxbrew_test_mode && [[ -n "${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID:-}" ]]; then
    actual_gid="${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID}"
  else
    actual_gid="$(omd_shared_linuxbrew_group_gid "${manager_group}" 2>/dev/null || true)"
  fi
  [[ "${actual_uid}" == "${expected_uid}" && "${actual_gid}" == "${expected_gid}" ]] || return 1
  [[ "$(omd_shared_linuxbrew_stat_uid "${resolved_prefix}")" == "${expected_uid}" ]] || return 1
  [[ "$(omd_shared_linuxbrew_stat_gid "${resolved_prefix}")" == "${expected_gid}" ]] || return 1
  if ! omd_shared_linuxbrew_test_mode; then
    [[ "$(omd_shared_linuxbrew_stat_uid "${manifest}")" == "0" ]] || return 1
    [[ "$(omd_shared_linuxbrew_stat_gid "${manifest}")" == "0" ]] || return 1
    (( (8#$(omd_shared_linuxbrew_stat_mode "${manifest}") & 8#022) == 0 )) || return 1
    [[ "$(omd_shared_linuxbrew_stat_uid "$(omd_shared_linuxbrew_state_dir)")" == "0" ]] || return 1
    [[ "$(omd_shared_linuxbrew_stat_uid "$(omd_shared_linuxbrew_libexec_dir)/brew-gateway")" == "0" ]] || return 1
    [[ "$(omd_shared_linuxbrew_stat_uid "$(omd_shared_linuxbrew_libexec_dir)/brew-provisioner")" == "0" ]] || return 1
  fi
  [[ -d "$(omd_shared_linuxbrew_state_dir)/inventory" && ! -L "$(omd_shared_linuxbrew_state_dir)/inventory" ]] || return 1
  [[ -f "$(omd_shared_linuxbrew_state_dir)/locks/mutation.lock" && ! -L "$(omd_shared_linuxbrew_state_dir)/locks/mutation.lock" ]] || return 1
}

omd_shared_linuxbrew_managed() {
  omd_shared_linuxbrew_validate
}

omd_shared_linuxbrew_current_user_enrolled() {
  local user uid record
  omd_shared_linuxbrew_managed || return 1
  if omd_shared_linuxbrew_test_mode && [[ -n "${OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER:-}" ]]; then
    user="${OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER}"
    uid="${OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_UID:-$(id -u)}"
  else
    user="$(id -un)"
    uid="$(id -u)"
  fi
  [[ "${user}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || return 1
  record="$(omd_shared_linuxbrew_state_dir)/members/${user}"
  [[ -f "${record}" && ! -L "${record}" ]] || return 1
  grep -Fqx "managed_by=oh-my-devpod" "${record}" || return 1
  grep -Fqx "user=${user}" "${record}" || return 1
  grep -Fqx "uid=${uid}" "${record}"
}

omd_shared_linuxbrew_marker_path() {
  local formula="$1"
  [[ "${formula}" =~ ^[a-z0-9][a-z0-9@+_.-]*$ ]] || return 2
  printf '%s/inventory/%s\n' "$(omd_shared_linuxbrew_state_dir)" "${formula}"
}

omd_shared_linuxbrew_formula_managed() {
  local component="$1" formula="$2" marker prefix installation_id
  omd_shared_linuxbrew_managed || return 1
  omd_shared_linuxbrew_current_user_enrolled || return 1
  [[ "${component}" == "${formula}" ]] || return 1
  marker="$(omd_shared_linuxbrew_marker_path "${formula}")" || return
  [[ -f "${marker}" && ! -L "${marker}" ]] || return 1
  grep -qx 'managed_by=oh-my-devpod' "${marker}" || return 1
  grep -Fqx "component=${component}" "${marker}" || return 1
  grep -Fqx 'kind=brew-formula' "${marker}" || return 1
  grep -Fqx "artifact=${formula}" "${marker}" || return 1
  grep -Fqx 'state=managed' "${marker}" || return 1
  prefix="$(omd_shared_linuxbrew_prefix)"
  grep -Fqx "brew_prefix=${prefix}" "${marker}" || return 1
  installation_id="$(omd_shared_linuxbrew_manifest_value installation_id || true)"
  grep -Fqx "installation_id=${installation_id}" "${marker}" || return 1
}

omd_shared_linuxbrew_formula_prefix() {
  local component="$1" formula="$2"
  omd_shared_linuxbrew_formula_managed "${component}" "${formula}" || return 1
  omd_shared_linuxbrew_prefix
}

omd_shared_linuxbrew_install_controller() {
  local bundle_root="$1" source_controller source_gateway libexec_dir sudo_bin
  source_controller="${bundle_root}/build/omd-brew-provisioner.sh"
  source_gateway="${bundle_root}/build/omd-brew-gateway.sh"
  libexec_dir="$(omd_shared_linuxbrew_libexec_dir)"
  [[ -f "${source_controller}" && ! -L "${source_controller}" ]] || {
    printf 'error: shared Linuxbrew provisioner is missing: %s\n' "${source_controller}" >&2
    return 1
  }
  [[ -f "${source_gateway}" && ! -L "${source_gateway}" ]] || {
    printf 'error: shared Linuxbrew gateway is missing: %s\n' "${source_gateway}" >&2
    return 1
  }

  if omd_shared_linuxbrew_test_mode; then
    mkdir -p "${libexec_dir}/bin"
    install -m 0755 "${source_controller}" "${libexec_dir}/brew-provisioner"
    install -m 0755 "${source_gateway}" "${libexec_dir}/brew-gateway"
    return 0
  fi

  sudo_bin="${OHMYDEVPOD_SUDO_BIN:-sudo}"
  command -v "${sudo_bin}" >/dev/null 2>&1 || {
    printf 'error: sudo is required to initialize or join shared Linuxbrew\n' >&2
    return 1
  }
  "${sudo_bin}" -- install -d -o root -g root -m 0755 "${libexec_dir}" "${libexec_dir}/bin"
  "${sudo_bin}" -- install -o root -g root -m 0755 "${source_controller}" "${libexec_dir}/brew-provisioner"
  "${sudo_bin}" -- install -o root -g root -m 0755 "${source_gateway}" "${libexec_dir}/brew-gateway"
}

omd_shared_linuxbrew_provision() {
  local bundle_root="$1" mirror_profile="${2:-upstream}" controller sudo_bin
  case "${mirror_profile}" in upstream|cn) ;; *) return 2 ;; esac
  omd_shared_linuxbrew_install_controller "${bundle_root}" || return
  controller="$(omd_shared_linuxbrew_libexec_dir)/brew-provisioner"
  if omd_shared_linuxbrew_test_mode; then
    "${controller}" ensure "${mirror_profile}"
    return
  fi
  sudo_bin="${OHMYDEVPOD_SUDO_BIN:-sudo}"
  "${sudo_bin}" -- "${controller}" ensure "${mirror_profile}"
}

omd_shared_linuxbrew_set_profile() {
  local profile="$1" controller sudo_bin
  case "${profile}" in upstream|cn) ;; *) return 2 ;; esac
  omd_shared_linuxbrew_managed || return 1
  controller="$(omd_shared_linuxbrew_libexec_dir)/brew-provisioner"
  [[ -x "${controller}" && ! -L "${controller}" ]] || return 1
  if omd_shared_linuxbrew_test_mode; then
    "${controller}" source-profile "${profile}"
    return
  fi
  sudo_bin="${OHMYDEVPOD_SUDO_BIN:-sudo}"
  "${sudo_bin}" -n -- "${controller}" source-profile "${profile}"
}

omd_shared_linuxbrew_activate_if_present() {
  local bundle_root="$1" mirror_profile="${2:-upstream}"
  omd_shared_linuxbrew_enabled || return 0
  omd_shared_linuxbrew_activation_candidate || return 0
  omd_shared_linuxbrew_provision "${bundle_root}" "${mirror_profile}"
}
