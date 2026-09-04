#!/usr/bin/env bash
set -euo pipefail

production_libexec="/usr/local/libexec/oh-my-devpod"
production_controller="${production_libexec}/brew-provisioner"
resolved_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
if command -v readlink >/dev/null 2>&1; then
  resolved_self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${resolved_self}")"
fi

if [[ "${resolved_self}" == "${production_controller}" ]]; then
  test_mode=0
  prefix="/home/linuxbrew/.linuxbrew"
  state_dir="/var/lib/oh-my-devpod/linuxbrew"
  libexec_dir="${production_libexec}"
  sudoers_file="/etc/sudoers.d/oh-my-devpod-brew"
  service_user="omd-brew"
  manager_group="omd-brew"
  global_brew="/usr/local/bin/brew"
  profile_file="/etc/profile.d/oh-my-devpod-brew.sh"
else
  test_mode="${OHMYDEVPOD_SHARED_BREW_TEST_MODE:-0}"
  prefix="${OHMYDEVPOD_SHARED_BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  state_dir="${OHMYDEVPOD_SHARED_BREW_STATE_DIR:-/var/lib/oh-my-devpod/linuxbrew}"
  libexec_dir="${OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR:-${production_libexec}}"
  sudoers_file="${OHMYDEVPOD_SHARED_BREW_SUDOERS_FILE:-/etc/sudoers.d/oh-my-devpod-brew}"
  service_user="${OHMYDEVPOD_SHARED_BREW_SERVICE_USER:-omd-brew}"
  manager_group="${OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP:-omd-brew}"
  global_brew="${OHMYDEVPOD_SHARED_BREW_GLOBAL_BIN:-${libexec_dir}/global-bin/brew}"
  profile_file="${OHMYDEVPOD_SHARED_BREW_PROFILE_FILE:-${state_dir}/profile.d/oh-my-devpod-brew.sh}"
fi

manifest="${state_dir}/manifest"
inventory_dir="${state_dir}/inventory"
lock_dir="${state_dir}/locks"
lock_file="${lock_dir}/mutation.lock"
members_dir="${state_dir}/members"
service_home="${state_dir}/service-home"
stable_gateway="${libexec_dir}/brew-gateway"

fail() {
  printf 'error: shared Linuxbrew provisioner: %s\n' "$*" >&2
  exit 1
}

valid_account_name() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]
}

valid_formula_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9@+_.-]*$ ]]
}

require_root() {
  [[ "${test_mode}" == "1" || "$(id -u)" -eq 0 ]] || fail "must run as root"
}

stat_uid() {
  if stat -c '%u' "$1" >/dev/null 2>&1; then
    stat -c '%u' "$1"
  else
    stat -f '%u' "$1"
  fi
}

stat_gid() {
  if stat -c '%g' "$1" >/dev/null 2>&1; then
    stat -c '%g' "$1"
  else
    stat -f '%g' "$1"
  fi
}

stat_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

path_has_no_symlink_components() {
  local path="$1" current="/" part
  local -a parts
  [[ "${path}" == /* ]] || return 1
  IFS='/' read -r -a parts <<< "${path#/}"
  for part in "${parts[@]}"; do
    [[ -n "${part}" ]] || continue
    if [[ "${current}" == "/" ]]; then
      current="/${part}"
    else
      current="${current}/${part}"
    fi
    [[ ! -L "${current}" ]] || return 1
  done
}

trusted_storage_root() {
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_ROOT:-/}"
  else
    printf '/\n'
  fi
}

trusted_storage_uid() {
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_UID:-$(id -u)}"
  else
    printf '0\n'
  fi
}

trusted_storage_gid() {
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_GID:-$(id -g)}"
  else
    printf '0\n'
  fi
}

path_is_within() {
  local path="$1" root="$2"
  [[ "${path}" == "${root}" || "${path}" == "${root%/}"/* ]]
}

trusted_storage_directory() {
  local path="$1" expected_uid="$2" expected_gid="$3" mode
  [[ -d "${path}" && ! -L "${path}" ]] || return 1
  [[ "$(stat_uid "${path}")" == "${expected_uid}" ]] || return 1
  mode="$(stat_mode "${path}")" || return 1
  [[ "${mode}" =~ ^[0-7]{3,4}$ ]] || return 1
  (( (8#${mode} & 8#002) == 0 )) || return 1
  if (( (8#${mode} & 8#020) != 0 )); then
    [[ "$(stat_gid "${path}")" == "${expected_gid}" ]] || return 1
  fi
}

trusted_storage_parent_chain() {
  local path="$1" root="$2" expected_uid="$3" expected_gid="$4"
  local parent relative current part
  parent="$(dirname "${path}")"
  path_is_within "${parent}" "${root}" || return 1
  trusted_storage_directory "${root}" "${expected_uid}" "${expected_gid}" || return 1
  if [[ "${root}" == "/" ]]; then
    relative="${parent#/}"
    current="/"
  elif [[ "${parent}" == "${root}" ]]; then
    relative=""
    current="${root}"
  else
    relative="${parent#"${root%/}/"}"
    current="${root%/}"
  fi
  while IFS= read -r part; do
    [[ -n "${part}" ]] || continue
    if [[ "${current}" == "/" ]]; then
      current="/${part}"
    else
      current="${current}/${part}"
    fi
    if [[ -L "${current}" ]]; then
      [[ "$(stat_uid "${current}")" == "${expected_uid}" ]] || return 1
    else
      trusted_storage_directory "${current}" "${expected_uid}" "${expected_gid}" || return 1
    fi
  done < <(tr '/' '\n' <<< "${relative}")
}

trusted_prefix_parent_resolved() {
  local candidate="$1" root expected_uid expected_gid parent resolved_parent resolved_candidate
  [[ "${candidate}" == /* ]] || return 1
  parent="$(dirname "${candidate}")"
  [[ -d "${parent}" ]] || return 1
  root="$(trusted_storage_root)"
  root="$(cd "${root}" 2>/dev/null && pwd -P)" || return 1
  expected_uid="$(trusted_storage_uid)"
  expected_gid="$(trusted_storage_gid)"
  [[ "${expected_uid}" =~ ^[0-9]+$ && "${expected_gid}" =~ ^[0-9]+$ ]] || return 1
  trusted_storage_parent_chain \
    "${candidate}" "${root}" "${expected_uid}" "${expected_gid}" || return 1
  resolved_parent="$(cd "${parent}" 2>/dev/null && pwd -P)" || return 1
  resolved_candidate="${resolved_parent%/}/$(basename "${candidate}")"
  trusted_storage_parent_chain \
    "${resolved_candidate}" "${root}" "${expected_uid}" "${expected_gid}" || return 1
  printf '%s\n' "${resolved_candidate}"
}

trusted_prefix_resolved() {
  local candidate="$1" resolved expected_resolved
  [[ "${candidate}" == /* && -d "${candidate}" && ! -L "${candidate}" ]] || return 1
  resolved="$(cd "${candidate}" 2>/dev/null && pwd -P)" || return 1
  [[ "${resolved}" == /* && -d "${resolved}" && ! -L "${resolved}" ]] || return 1
  if path_has_no_symlink_components "${candidate}"; then
    [[ "${resolved}" == "${candidate}" ]] || return 1
    printf '%s\n' "${resolved}"
    return 0
  fi
  expected_resolved="$(trusted_prefix_parent_resolved "${candidate}")" || return 1
  [[ "${resolved}" == "${expected_resolved}" ]] || return 1
  printf '%s\n' "${resolved}"
}

trusted_prefixes_equivalent() {
  local first="$1" second="$2" first_resolved second_resolved
  [[ "${first}" == /* && "${second}" == /* ]] || return 1
  first_resolved="$(trusted_prefix_resolved "${first}")" || return 1
  second_resolved="$(trusted_prefix_resolved "${second}")" || return 1
  [[ "${first_resolved}" == "${second_resolved}" ]]
}

prepare_prefix_parent() {
  if path_has_no_symlink_components "$(dirname "${prefix}")"; then
    ensure_safe_parent "${prefix}"
    return 0
  fi
  trusted_prefix_parent_resolved "${prefix}" >/dev/null ||
    fail "shared Brew prefix parent is not controlled by the trusted storage root"
}

ensure_safe_parent() {
  local path="$1" parent
  parent="$(dirname "${path}")"
  path_has_no_symlink_components "${parent}" || fail "unsafe symlink in path: ${parent}"
  mkdir -p "${parent}"
  path_has_no_symlink_components "${parent}" || fail "unsafe symlink in path: ${parent}"
}

manifest_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "${manifest}" | head -n 1
}

new_installation_id() {
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    tr -d '[:space:]' < /proc/sys/kernel/random/uuid
  elif command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    printf '%08x-%04x-%04x-%04x-%012x\n' "$(date +%s)" "$$" "${RANDOM}" "${RANDOM}" "${RANDOM}"
  fi
}

account_uid() {
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_UID:-$(id -u)}"
  else
    id -u "$1"
  fi
}

group_gid() {
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID:-$(id -g)}"
  else
    getent group "$1" | awk -F: '{print $3}'
  fi
}

passwd_home() {
  local user="$1"
  if [[ "${test_mode}" == "1" ]]; then
    if [[ "${user}" == "${service_user}" ]]; then
      printf '%s\n' "${service_home}"
    else
      printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_TARGET_HOME:-${HOME}}"
    fi
  else
    getent passwd "${user}" | awk -F: '{print $6}'
  fi
}

invoking_user() {
  local user
  if [[ "${test_mode}" == "1" ]]; then
    user="${OHMYDEVPOD_SHARED_BREW_TEST_TARGET_USER:-$(id -un)}"
  else
    user="${SUDO_USER:-}"
    [[ -n "${user}" && "${user}" != "root" ]] || fail "cannot determine the non-root user to enroll; run through sudo from that account"
  fi
  valid_account_name "${user}" || fail "invalid invoking user"
  printf '%s\n' "${user}"
}

run_as_account() {
  local user="$1" home="$2"
  shift 2
  if [[ "${test_mode}" == "1" || "$(id -un)" == "${user}" ]]; then
    env -i HOME="${home}" USER="${user}" PATH="/usr/local/bin:/usr/bin:/bin:${prefix}/bin" OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OMD_TEST_BREW_LOG="${OMD_TEST_BREW_LOG:-/dev/null}" "$@"
  elif command -v runuser >/dev/null 2>&1; then
    runuser -u "${user}" -- env -i HOME="${home}" USER="${user}" PATH="/usr/local/bin:/usr/bin:/bin:${prefix}/bin" "$@"
  else
    sudo -n -H -u "${user}" -- env -i HOME="${home}" USER="${user}" PATH="/usr/local/bin:/usr/bin:/bin:${prefix}/bin" "$@"
  fi
}

ensure_accounts() {
  local nologin
  if [[ "${test_mode}" == "1" ]]; then
    return 0
  fi
  valid_account_name "${service_user}" || fail "invalid service user"
  valid_account_name "${manager_group}" || fail "invalid manager group"
  if [[ -e "${manifest}" || -L "${manifest}" ]]; then
    getent group "${manager_group}" >/dev/null || fail "shared manager group is missing"
    id -u "${service_user}" >/dev/null 2>&1 || fail "shared service account is missing"
    [[ "$(id -g "${service_user}")" == "$(group_gid "${manager_group}")" ]] || fail "service account primary group mismatch"
    return 0
  fi
  if ! getent group "${manager_group}" >/dev/null; then
    groupadd --system "${manager_group}"
  fi
  if ! id -u "${service_user}" >/dev/null 2>&1; then
    ensure_safe_parent "${service_home}"
    nologin="$(command -v nologin || printf '/usr/sbin/nologin')"
    useradd --system --gid "${manager_group}" --home-dir "${service_home}" --create-home --shell "${nologin}" "${service_user}"
  fi
  [[ "$(id -g "${service_user}")" == "$(group_gid "${manager_group}")" ]] || fail "service account primary group mismatch"
}

prepare_state_layout() {
  local service_uid service_gid
  ensure_safe_parent "${state_dir}"
  prepare_prefix_parent
  path_has_no_symlink_components "${libexec_dir}" || fail "unsafe libexec path"
  [[ ! -e "${state_dir}" || -d "${state_dir}" ]] || fail "shared state path is not a directory"
  [[ ! -L "${state_dir}" ]] || fail "shared state path is a symlink"
  mkdir -p "${state_dir}" "${inventory_dir}" "${lock_dir}" "${members_dir}" "${service_home}" "${libexec_dir}/bin"
  path_has_no_symlink_components "${state_dir}" || fail "unsafe shared state path"
  [[ ! -L "${inventory_dir}" && ! -L "${lock_dir}" && ! -L "${members_dir}" && ! -L "${service_home}" ]] || fail "unsafe shared state subdirectory"
  [[ ! -L "${lock_file}" ]] || fail "shared mutation lock is a symlink"
  : > "${lock_file}"
  service_uid="$(account_uid "${service_user}")"
  service_gid="$(group_gid "${manager_group}")"
  if [[ "${test_mode}" != "1" ]]; then
    chown root:root "${state_dir}" "${lock_dir}" "${members_dir}"
    chmod 0755 "${state_dir}" "${lock_dir}" "${members_dir}"
    chown "${service_uid}:${service_gid}" "${inventory_dir}" "${service_home}" "${lock_file}"
    chmod 0755 "${inventory_dir}"
    chmod 0750 "${service_home}"
    chmod 0600 "${lock_file}"
  fi
}

validate_policy_targets() {
  local expected_link existing_target
  expected_link="${libexec_dir}/bin/brew"
  if [[ -e "${global_brew}" || -L "${global_brew}" ]]; then
    [[ -L "${global_brew}" ]] || fail "refusing to replace existing ${global_brew}"
    existing_target="$(readlink "${global_brew}")"
    [[ "${existing_target}" == "${expected_link}" ]] || fail "refusing to replace external Brew command at ${global_brew}"
  fi
  if [[ -e "${profile_file}" || -L "${profile_file}" ]]; then
    [[ -f "${profile_file}" && ! -L "${profile_file}" ]] || fail "refusing unsafe shell profile activation path"
    head -n 1 "${profile_file}" | grep -Fqx '# Generated by oh-my-devpod. Shared Linuxbrew gateway.' || fail "refusing to replace existing shell profile activation"
  fi
  if [[ -e "${sudoers_file}" || -L "${sudoers_file}" ]]; then
    [[ -f "${sudoers_file}" && ! -L "${sudoers_file}" ]] || fail "refusing unsafe sudoers policy path"
    head -n 1 "${sudoers_file}" | grep -Fqx '# Generated by oh-my-devpod. Shared Linuxbrew policy.' || fail "refusing to replace existing sudoers policy"
  fi
}

install_policy() {
  local link temporary sudoers_tmp global_tmp profile_tmp existing_target
  [[ -f "${stable_gateway}" && ! -L "${stable_gateway}" ]] || fail "fixed Brew gateway is missing"
  [[ "${test_mode}" == "1" || "$(stat_uid "${stable_gateway}")" == "0" ]] || fail "fixed Brew gateway is not root-owned"
  [[ "${test_mode}" == "1" || "$(stat_gid "${stable_gateway}")" == "0" ]] || fail "fixed Brew gateway group is not root"
  link="${libexec_dir}/bin/brew"
  temporary="${libexec_dir}/bin/.brew.$$"
  ln -s ../brew-gateway "${temporary}"
  mv -f "${temporary}" "${link}"

  ensure_safe_parent "${global_brew}"
  if [[ -e "${global_brew}" || -L "${global_brew}" ]]; then
    [[ -L "${global_brew}" ]] || fail "refusing to replace existing ${global_brew}"
    existing_target="$(readlink "${global_brew}")"
    [[ "${existing_target}" == "${link}" ]] || fail "refusing to replace external Brew command at ${global_brew}"
  else
    global_tmp="$(dirname "${global_brew}")/.brew.$$"
    ln -s "${link}" "${global_tmp}"
    mv -f "${global_tmp}" "${global_brew}"
  fi

  ensure_safe_parent "${profile_file}"
  profile_tmp="${profile_file}.tmp.$$"
  {
    printf '%s\n' '# Generated by oh-my-devpod. Shared Linuxbrew gateway.'
    printf '%s\n' 'case " $(id -nG 2>/dev/null) " in'
    printf '  *" %s "*)\n' "${manager_group}"
    printf '    PATH="%s:%s/bin:%s/sbin:$PATH"\n' "${libexec_dir}/bin" "${prefix}" "${prefix}"
    printf '%s\n' '    export PATH'
    printf '%s\n' '    ;;'
    printf '%s\n' 'esac'
  } > "${profile_tmp}"
  chmod 0644 "${profile_tmp}"
  if [[ "${test_mode}" != "1" ]]; then chown root:root "${profile_tmp}"; fi
  mv -f "${profile_tmp}" "${profile_file}"

  ensure_safe_parent "${sudoers_file}"
  sudoers_tmp="${sudoers_file}.tmp.$$"
  {
    printf '%s\n' '# Generated by oh-my-devpod. Shared Linuxbrew policy.'
    printf '%%%s ALL=(%s) NOPASSWD: %s --service *\n' "${manager_group}" "${service_user}" "${stable_gateway}"
    printf '%%%s ALL=(root) NOPASSWD: %s source-profile upstream\n' "${manager_group}" "${libexec_dir}/brew-provisioner"
    printf '%%%s ALL=(root) NOPASSWD: %s source-profile cn\n' "${manager_group}" "${libexec_dir}/brew-provisioner"
  } > "${sudoers_tmp}"
  chmod 0440 "${sudoers_tmp}"
  if [[ "${test_mode}" != "1" ]]; then
    chown root:root "${sudoers_tmp}"
    command -v visudo >/dev/null 2>&1 || fail "visudo is required"
    visudo -cf "${sudoers_tmp}" >/dev/null || fail "generated sudoers policy is invalid"
  fi
  mv -f "${sudoers_tmp}" "${sudoers_file}"
}

install_dependencies() {
  [[ "${test_mode}" == "1" ]] && return 0
  command -v apt-get >/dev/null 2>&1 || fail "Ubuntu apt-get is required"
  apt-get update
  apt-get install -y build-essential procps curl file git ca-certificates util-linux
}

brew_remote_for_profile() {
  case "$1" in
    upstream) printf '%s\n' 'https://github.com/Homebrew/brew.git' ;;
    cn) printf '%s\n' 'https://mirrors.ustc.edu.cn/brew.git' ;;
    *) return 1 ;;
  esac
}

initialize_prefix() {
  local mirror_profile="$1" remote test_brew
  [[ ! -e "${prefix}" && ! -L "${prefix}" ]] || fail "refusing to initialize over existing path: ${prefix}"
  mkdir -p "${prefix}"
  if [[ "${test_mode}" == "1" ]]; then
    test_brew="${OHMYDEVPOD_SHARED_BREW_TEST_REAL_BIN:-}"
    [[ -x "${test_brew}" && ! -L "${test_brew}" ]] || fail "test mode requires a fake Brew backend"
    mkdir -p "${prefix}/bin" "${prefix}/Cellar"
    install -m 0755 "${test_brew}" "${prefix}/bin/brew"
    return 0
  fi

  install_dependencies
  chown "${service_user}:${manager_group}" "${prefix}"
  remote="$(brew_remote_for_profile "${mirror_profile}")" || fail "invalid mirror profile"
  run_as_account "${service_user}" "${service_home}" git clone --depth 1 "${remote}" "${prefix}"
  [[ -x "${prefix}/bin/brew" ]] || fail "Linuxbrew installation did not create ${prefix}/bin/brew"
}

user_for_uid() {
  local uid="$1"
  if [[ "${test_mode}" == "1" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_OWNER:-$(id -un)}"
  else
    getent passwd "${uid}" | awk -F: '{print $1}'
  fi
}

legacy_home_for_user() {
  local user="$1"
  if [[ "${test_mode}" == "1" && -n "${OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME:-}" ]]; then
    printf '%s\n' "${OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME}"
  else
    passwd_home "${user}"
  fi
}

validate_legacy_prefix() {
  local owner_uid owner_gid owner owner_home marker marker_uid reported
  [[ -d "${prefix}" && ! -L "${prefix}" && -x "${prefix}/bin/brew" ]] || fail "unmanaged-prefix-conflict: prefix is missing or unsafe"
  trusted_prefix_resolved "${prefix}" >/dev/null || fail "unmanaged-prefix-conflict: prefix path is not controlled by the trusted storage root"
  owner_uid="$(stat_uid "${prefix}")"
  owner_gid="$(stat_gid "${prefix}")"
  owner="$(user_for_uid "${owner_uid}")"
  [[ -n "${owner}" && "${owner}" != "root" ]] || fail "unmanaged-prefix-conflict: cannot resolve a non-root legacy owner"
  owner_home="$(legacy_home_for_user "${owner}")"
  [[ "${owner_home}" == /* && -d "${owner_home}" && ! -L "${owner_home}" ]] || fail "unmanaged-prefix-conflict: legacy owner home is unsafe"
  [[ "$(cd "${owner_home}" 2>/dev/null && pwd -P)" == "${owner_home}" ]] || fail "unmanaged-prefix-conflict: legacy owner home resolves through a symlink"
  marker="${owner_home}/.local/state/oh-my-devpod/managed/linuxbrew"
  [[ -f "${marker}" && ! -L "${marker}" ]] || fail "unmanaged-prefix-conflict: legacy OMD marker is missing"
  marker_uid="$(stat_uid "${marker}")"
  [[ "${test_mode}" == "1" || "${marker_uid}" == "${owner_uid}" ]] || fail "unmanaged-prefix-conflict: legacy marker owner mismatch"
  grep -qx 'managed_by=oh-my-devpod' "${marker}" || fail "unmanaged-prefix-conflict: invalid legacy marker"
  grep -qx 'component=linuxbrew' "${marker}" || fail "unmanaged-prefix-conflict: invalid legacy component"
  grep -qx 'kind=directory' "${marker}" || fail "unmanaged-prefix-conflict: invalid legacy marker kind"
  grep -Fqx "artifact=${prefix}" "${marker}" || fail "unmanaged-prefix-conflict: legacy marker does not match the prefix"
  if [[ -e "${prefix}/etc/homebrew/brew.env" || -L "${prefix}/etc/homebrew/brew.env" ]]; then
    source_profile_brew_env_is_managed "${prefix}/etc/homebrew/brew.env" || fail "unmanaged-prefix-conflict: legacy Homebrew source configuration was modified"
  fi
  reported="$(run_as_account "${owner}" "${owner_home}" "${prefix}/bin/brew" --prefix)"
  [[ "${reported}" == "${prefix}" ]] || fail "unmanaged-prefix-conflict: Brew reports another prefix"
  printf '%s\t%s\t%s\t%s\n' "${owner}" "${owner_uid}" "${owner_gid}" "${owner_home}"
}

write_inventory_record() {
  local formula="$1" installation_id="$2" state="$3" provenance="$4" destination="$5" temporary
  valid_formula_name "${formula}" || return 0
  temporary="${destination}.tmp.$$"
  {
    printf 'managed_by=oh-my-devpod\n'
    printf 'component=%s\n' "${formula}"
    printf 'kind=brew-formula\n'
    printf 'artifact=%s\n' "${formula}"
    printf 'brew_prefix=%s\n' "${prefix}"
    printf 'installation_id=%s\n' "${installation_id}"
    printf 'state=%s\n' "${state}"
    printf 'provenance=%s\n' "${provenance}"
  } > "${temporary}"
  mv -f "${temporary}" "${destination}"
}

legacy_formula_is_managed() {
  local owner_home="$1" formula="$2" owner_uid="${3:-}" marker marker_prefix
  marker="${owner_home}/.local/state/oh-my-devpod/managed/${formula}"
  [[ -f "${marker}" && ! -L "${marker}" ]] || return 1
  if [[ "${test_mode}" != "1" && -n "${owner_uid}" ]]; then
    [[ "$(stat_uid "${marker}")" == "${owner_uid}" ]] || return 1
  fi
  grep -qx 'managed_by=oh-my-devpod' "${marker}" || return 1
  grep -Fqx "component=${formula}" "${marker}" || return 1
  grep -qx 'kind=brew-formula' "${marker}" || return 1
  grep -Fqx "artifact=${formula}" "${marker}" || return 1
  marker_prefix="$(sed -n 's/^brew_prefix=//p' "${marker}")"
  [[ -n "${marker_prefix}" ]] || return 1
  trusted_prefixes_equivalent "${marker_prefix}" "${prefix}"
}

stage_legacy_inventory() {
  local owner_home="$1" owner_uid="$2" installation_id="$3" staging="$4" formula state provenance
  mkdir -p "${staging}"
  [[ -d "${prefix}/Cellar" ]] || return 0
  while IFS= read -r formula; do
    [[ -n "${formula}" ]] || continue
    state=external
    provenance=legacy-preexisting
    if legacy_formula_is_managed "${owner_home}" "${formula}" "${owner_uid}"; then
      state=managed
      provenance=legacy-marker
    fi
    write_inventory_record "${formula}" "${installation_id}" "${state}" "${provenance}" "${staging}/${formula}"
  done < <(find "${prefix}/Cellar" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort -u)
}

legacy_inventory_record_is_recoverable() {
  local record="$1" formula="$2" installation_id="$3"
  [[ -f "${record}" && ! -L "${record}" ]] || return 1
  grep -qx 'managed_by=oh-my-devpod' "${record}" || return 1
  grep -Fqx "component=${formula}" "${record}" || return 1
  grep -qx 'kind=brew-formula' "${record}" || return 1
  grep -Fqx "artifact=${formula}" "${record}" || return 1
  grep -Fqx "brew_prefix=${prefix}" "${record}" || return 1
  grep -Fqx "installation_id=${installation_id}" "${record}" || return 1
  grep -qx 'state=external' "${record}" || return 1
  grep -qx 'provenance=legacy-preexisting' "${record}"
}

member_identity_for_recovery() {
  local record="$1" user uid home mode current_uid current_home
  [[ -f "${record}" && ! -L "${record}" ]] || return 1
  user="$(basename "${record}")"
  valid_account_name "${user}" || return 1
  if [[ "${test_mode}" != "1" ]]; then
    [[ "$(stat_uid "${record}")" == "0" && "$(stat_gid "${record}")" == "0" ]] || return 1
    mode="$(stat_mode "${record}")" || return 1
    [[ "${mode}" =~ ^[0-7]{3,4}$ ]] || return 1
    (( (8#${mode} & 8#022) == 0 )) || return 1
  fi
  grep -qx 'managed_by=oh-my-devpod' "${record}" || return 1
  grep -Fqx "user=${user}" "${record}" || return 1
  uid="$(sed -n 's/^uid=//p' "${record}")"
  home="$(sed -n 's/^home=//p' "${record}")"
  [[ "${uid}" =~ ^[0-9]+$ ]] || return 1
  [[ "${home}" == /* && -d "${home}" && ! -L "${home}" ]] || return 1
  if [[ "${test_mode}" != "1" ]]; then
    current_uid="$(id -u "${user}" 2>/dev/null)" || return 1
    current_home="$(passwd_home "${user}")"
    [[ "${uid}" == "${current_uid}" && "${home}" == "${current_home}" ]] || return 1
  fi
  printf '%s\t%s\n' "${uid}" "${home}"
}

recover_legacy_inventory() {
  local installation_id service_uid service_gid record formula member identity member_uid member_home recovered
  installation_id="$(manifest_value installation_id || true)"
  [[ -n "${installation_id}" ]] || return 0
  service_uid="$(account_uid "${service_user}")"
  service_gid="$(group_gid "${manager_group}")"
  while IFS= read -r -d '' record; do
    formula="$(basename "${record}")"
    valid_formula_name "${formula}" || continue
    legacy_inventory_record_is_recoverable "${record}" "${formula}" "${installation_id}" || continue
    while IFS= read -r -d '' member; do
      identity="$(member_identity_for_recovery "${member}" || true)"
      [[ -n "${identity}" ]] || continue
      IFS=$'\t' read -r member_uid member_home <<< "${identity}"
      legacy_formula_is_managed "${member_home}" "${formula}" "${member_uid}" || continue
      recovered="${inventory_dir}/.${formula}.recovered.$$"
      write_inventory_record "${formula}" "${installation_id}" managed legacy-marker-recovered "${recovered}"
      chmod 0644 "${recovered}"
      if [[ "${test_mode}" != "1" ]]; then
        chown "${service_uid}:${service_gid}" "${recovered}"
      fi
      mv -f "${recovered}" "${record}"
      break
    done < <(find "${members_dir}" -mindepth 1 -maxdepth 1 -type f -print0)
  done < <(find "${inventory_dir}" -mindepth 1 -maxdepth 1 -type f -print0)
}

write_manifest() {
  local mirror_profile="$1" installation_id="$2" service_uid="$3" service_gid="$4" destination="$5" resolved_prefix
  resolved_prefix="$(trusted_prefix_resolved "${prefix}")" || fail "shared Brew prefix path is not trusted"
  {
    printf 'schema_version=2\n'
    printf 'managed_by=oh-my-devpod\n'
    printf 'mode=shared-service-account\n'
    printf 'prefix=%s\n' "${prefix}"
    printf 'resolved_prefix=%s\n' "${resolved_prefix}"
    printf 'service_user=%s\n' "${service_user}"
    printf 'service_uid=%s\n' "${service_uid}"
    printf 'manager_group=%s\n' "${manager_group}"
    printf 'service_gid=%s\n' "${service_gid}"
    printf 'mirror_profile=%s\n' "${mirror_profile}"
    printf 'installation_id=%s\n' "${installation_id}"
  } > "${destination}"
  chmod 0644 "${destination}"
}

validate_existing_manifest() {
  local expected_uid expected_gid schema resolved_prefix recorded_resolved_prefix
  [[ -f "${manifest}" && ! -L "${manifest}" ]] || fail "shared manifest is missing or unsafe"
  path_has_no_symlink_components "${state_dir}" || fail "shared state path contains a symlink"
  schema="$(manifest_value schema_version || true)"
  case "${schema}" in 1|2) ;; *) fail "unsupported shared manifest schema" ;; esac
  [[ "$(manifest_value managed_by || true)" == "oh-my-devpod" ]] || fail "shared manifest ownership mismatch"
  [[ "$(manifest_value mode || true)" == "shared-service-account" ]] || fail "shared manifest mode mismatch"
  [[ "$(manifest_value prefix || true)" == "${prefix}" ]] || fail "shared manifest prefix mismatch"
  [[ "$(manifest_value service_user || true)" == "${service_user}" ]] || fail "shared manifest service user mismatch"
  [[ "$(manifest_value manager_group || true)" == "${manager_group}" ]] || fail "shared manifest manager group mismatch"
  expected_uid="$(account_uid "${service_user}")"
  expected_gid="$(group_gid "${manager_group}")"
  [[ "$(manifest_value service_uid || true)" == "${expected_uid}" ]] || fail "shared manifest service UID mismatch"
  [[ "$(manifest_value service_gid || true)" == "${expected_gid}" ]] || fail "shared manifest service GID mismatch"
  [[ "$(manifest_value installation_id || true)" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || fail "shared manifest installation ID is invalid"
  [[ -x "${prefix}/bin/brew" && ! -L "${prefix}" ]] || fail "shared Brew backend is missing or unsafe"
  resolved_prefix="$(trusted_prefix_resolved "${prefix}")" || fail "shared Brew prefix path is not trusted"
  if [[ "${schema}" == "1" ]]; then
    recorded_resolved_prefix="${prefix}"
  else
    recorded_resolved_prefix="$(manifest_value resolved_prefix || true)"
  fi
  [[ "${resolved_prefix}" == "${recorded_resolved_prefix}" ]] || fail "shared Brew resolved prefix mismatch"
  [[ "${test_mode}" == "1" || "$(stat_uid "${resolved_prefix}")" == "${expected_uid}" ]] || fail "shared Brew prefix owner mismatch"
  [[ "${test_mode}" == "1" || "$(stat_gid "${resolved_prefix}")" == "${expected_gid}" ]] || fail "shared Brew prefix group mismatch"
  if [[ "${test_mode}" != "1" ]]; then
    [[ "$(stat_uid "${manifest}")" == "0" && "$(stat_gid "${manifest}")" == "0" ]] || fail "shared manifest is not root-owned"
    (( (8#$(stat_mode "${manifest}") & 8#022) == 0 )) || fail "shared manifest is writable by non-root users"
    [[ "$(stat_uid "${state_dir}")" == "0" ]] || fail "shared state directory is not root-owned"
    [[ "$(stat_uid "${libexec_dir}/brew-provisioner")" == "0" && "$(stat_uid "${stable_gateway}")" == "0" ]] || fail "shared controllers are not root-owned"
  fi
}

initialize_shared_state() {
  local mirror_profile="$1" installation_id service_uid service_gid manifest_tmp created_prefix=0
  local legacy_info="" legacy_owner="" legacy_uid="" legacy_gid="" legacy_home="" inventory_staging=""
  installation_id="$(new_installation_id)"
  service_uid="$(account_uid "${service_user}")"
  service_gid="$(group_gid "${manager_group}")"
  manifest_tmp="${state_dir}/.manifest.$$"
  inventory_staging="${state_dir}/.inventory.$$"
  [[ -z "$(find "${inventory_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]] || fail "shared inventory exists without a valid manifest"

  if [[ -e "${prefix}" || -L "${prefix}" ]]; then
    legacy_info="$(validate_legacy_prefix)"
    IFS=$'\t' read -r legacy_owner legacy_uid legacy_gid legacy_home <<< "${legacy_info}"
    stage_legacy_inventory "${legacy_home}" "${legacy_uid}" "${installation_id}" "${inventory_staging}"
  else
    created_prefix=1
    if ! initialize_prefix "${mirror_profile}"; then
      rm -rf "${prefix}"
      fail "could not initialize the shared Brew prefix"
    fi
    mkdir -p "${inventory_staging}"
  fi
  write_manifest "${mirror_profile}" "${installation_id}" "${service_uid}" "${service_gid}" "${manifest_tmp}"

  if [[ "${test_mode}" != "1" ]]; then
    if ! chown -R "${service_uid}:${service_gid}" "${prefix}"; then
      [[ "${created_prefix}" != "1" ]] || rm -rf "${prefix}"
      rm -rf "${inventory_staging}" "${manifest_tmp}"
      fail "could not transfer the Brew prefix to the service account"
    fi
  fi
  if [[ "${mirror_profile}" == "cn" ]]; then
    mkdir -p "${prefix}/etc/homebrew"
    source_profile_brew_env > "${state_dir}/.brew-env-new.$$"
    if [[ "${test_mode}" == "1" ]]; then
      install -m 0644 "${state_dir}/.brew-env-new.$$" "${prefix}/etc/homebrew/brew.env"
    else
      install -o "${service_uid}" -g "${service_gid}" -m 0644 "${state_dir}/.brew-env-new.$$" "${prefix}/etc/homebrew/brew.env"
    fi
    rm -f "${state_dir}/.brew-env-new.$$"
  elif source_profile_brew_env_is_managed "${prefix}/etc/homebrew/brew.env"; then
    rm -f "${prefix}/etc/homebrew/brew.env"
  fi
  if ! cp -R "${inventory_staging}/." "${inventory_dir}/" 2>/dev/null; then
    if [[ "${test_mode}" != "1" && -n "${legacy_uid}" ]]; then
      chown -R "${legacy_uid}:${legacy_gid}" "${prefix}" || true
    elif [[ "${created_prefix}" == "1" ]]; then
      rm -rf "${prefix}"
    fi
    rm -rf "${inventory_staging}" "${manifest_tmp}"
    fail "could not publish the shared Brew inventory"
  fi
  rm -rf "${inventory_staging}"
  if [[ "${test_mode}" != "1" ]]; then
    chown -R "${service_uid}:${service_gid}" "${inventory_dir}"
  fi
  if ! mv -f "${manifest_tmp}" "${manifest}"; then
    if [[ "${test_mode}" != "1" && -n "${legacy_uid}" ]]; then
      chown -R "${legacy_uid}:${legacy_gid}" "${prefix}" || true
    elif [[ "${created_prefix}" == "1" ]]; then
      rm -rf "${prefix}"
    fi
    fail "could not publish the shared Brew manifest"
  fi
  if [[ "${test_mode}" != "1" ]]; then
    chown root:root "${manifest}"
  fi
  if [[ -n "${legacy_owner}" ]]; then
    printf '%s\n' "${legacy_owner}" > "${state_dir}/.legacy-owner"
  fi
}

enroll_user() {
  local target_user="$1" target_home uid record temporary
  valid_account_name "${target_user}" || fail "invalid target user"
  if [[ "${test_mode}" == "1" ]]; then
    uid="${OHMYDEVPOD_SHARED_BREW_TEST_TARGET_UID:-$(id -u)}"
  else
    uid="$(id -u "${target_user}")" || fail "target user does not exist"
  fi
  target_home="$(passwd_home "${target_user}")"
  [[ "${target_home}" == /* && -d "${target_home}" && ! -L "${target_home}" ]] || fail "target home is unsafe"
  if [[ "${test_mode}" != "1" ]]; then
    usermod -a -G "${manager_group}" "${target_user}"
  fi
  record="${members_dir}/${target_user}"
  [[ ! -L "${record}" ]] || fail "unsafe member record"
  temporary="${record}.tmp.$$"
  {
    printf 'managed_by=oh-my-devpod\n'
    printf 'user=%s\n' "${target_user}"
    printf 'uid=%s\n' "${uid}"
    printf 'home=%s\n' "${target_home}"
    printf 'enrolled_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${temporary}"
  chmod 0644 "${temporary}"
  mv -f "${temporary}" "${record}"
  if [[ "${test_mode}" != "1" ]]; then
    chown root:root "${record}"
  fi
}

remote_url() {
  local repository="$1"
  run_as_account "${service_user}" "${service_home}" git -C "${repository}" remote get-url origin 2>/dev/null
}

set_remote_url() {
  local repository="$1" target="$2"
  if remote_url "${repository}" >/dev/null 2>&1; then
    run_as_account "${service_user}" "${service_home}" git -C "${repository}" remote set-url origin "${target}"
  else
    run_as_account "${service_user}" "${service_home}" git -C "${repository}" remote add origin "${target}"
  fi
}

restore_remote_url() {
  local repository="$1" present="$2" value="$3"
  if [[ "${present}" == "1" ]]; then
    set_remote_url "${repository}" "${value}"
  elif remote_url "${repository}" >/dev/null 2>&1; then
    run_as_account "${service_user}" "${service_home}" git -C "${repository}" remote remove origin
  fi
}

source_profile_brew_env() {
  cat <<'EOF'
# Generated by oh-my-devpod. Shared host-scoped Homebrew source configuration.
HOMEBREW_BREW_GIT_REMOTE=https://mirrors.ustc.edu.cn/brew.git
HOMEBREW_CORE_GIT_REMOTE=https://mirrors.ustc.edu.cn/homebrew-core.git
HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
EOF
}

source_profile_brew_env_is_managed() {
  local path="$1" actual shared legacy
  [[ -f "${path}" && ! -L "${path}" ]] || return 1
  actual="$(cat "${path}")"
  shared="$(source_profile_brew_env)"
  legacy="${shared/#\# Generated by oh-my-devpod. Shared host-scoped Homebrew source configuration./\# Generated by oh-my-devpod. Managed native source configuration.}"
  [[ "${actual}" == "${shared}" || "${actual}" == "${legacy}" ]]
}

set_source_profile_locked() {
  local profile="$1" brew_remote core_remote core_dir env_path env_backup env_existed=0
  local brew_old="" brew_present=0 core_old="" core_present=0 manifest_tmp service_uid service_gid apply_failed=0
  case "${profile}" in
    upstream)
      brew_remote='https://github.com/Homebrew/brew.git'
      core_remote='https://github.com/Homebrew/homebrew-core.git'
      ;;
    cn)
      brew_remote='https://mirrors.ustc.edu.cn/brew.git'
      core_remote='https://mirrors.ustc.edu.cn/homebrew-core.git'
      ;;
    *)
      fail "invalid source profile"
      ;;
  esac
  validate_existing_manifest
  command -v git >/dev/null 2>&1 || fail "git is required to change the shared Brew source"
  [[ -d "${prefix}/.git" ]] || fail "shared Brew repository metadata is missing"
  core_dir="${prefix}/Library/Taps/homebrew/homebrew-core"
  env_path="${prefix}/etc/homebrew/brew.env"
  env_backup="${state_dir}/.brew-env.$$"
  manifest_tmp="${state_dir}/.manifest.$$"
  if brew_old="$(remote_url "${prefix}")"; then brew_present=1; fi
  if [[ -d "${core_dir}/.git" ]] && core_old="$(remote_url "${core_dir}")"; then core_present=1; fi
  if [[ -e "${env_path}" || -L "${env_path}" ]]; then
    source_profile_brew_env_is_managed "${env_path}" || fail "refusing to overwrite modified shared Homebrew source configuration"
    cp -p "${env_path}" "${env_backup}"
    env_existed=1
  fi

  if ! set_remote_url "${prefix}" "${brew_remote}"; then
    fail "could not update the shared Brew remote"
  fi
  if [[ -d "${core_dir}/.git" ]] && ! set_remote_url "${core_dir}" "${core_remote}"; then
    restore_remote_url "${prefix}" "${brew_present}" "${brew_old}" || true
    fail "could not update the shared Homebrew/core remote"
  fi

  service_uid="$(account_uid "${service_user}")"
  service_gid="$(group_gid "${manager_group}")"
  mkdir -p "$(dirname "${env_path}")" || apply_failed=1
  if [[ "${apply_failed}" == "0" && "${profile}" == "cn" ]]; then
    source_profile_brew_env > "${state_dir}/.brew-env-new.$$" || apply_failed=1
    if [[ "${apply_failed}" == "0" ]]; then
      install -o "${service_uid}" -g "${service_gid}" -m 0644 "${state_dir}/.brew-env-new.$$" "${env_path}" || apply_failed=1
    fi
    rm -f "${state_dir}/.brew-env-new.$$"
  elif [[ "${apply_failed}" == "0" ]]; then
    rm -f "${env_path}" || apply_failed=1
  fi
  if [[ "${apply_failed}" == "0" ]]; then
    awk -v profile="${profile}" 'BEGIN { changed=0 } /^mirror_profile=/ { print "mirror_profile=" profile; changed=1; next } { print } END { if (!changed) print "mirror_profile=" profile }' "${manifest}" > "${manifest_tmp}" || apply_failed=1
  fi
  if [[ "${apply_failed}" == "0" ]]; then
    chmod 0644 "${manifest_tmp}" || apply_failed=1
  fi
  if [[ "${apply_failed}" == "0" ]]; then
    mv -f "${manifest_tmp}" "${manifest}" || apply_failed=1
  fi
  if [[ "${apply_failed}" != "0" ]]; then
    restore_remote_url "${prefix}" "${brew_present}" "${brew_old}" || true
    [[ ! -d "${core_dir}/.git" ]] || restore_remote_url "${core_dir}" "${core_present}" "${core_old}" || true
    if [[ "${env_existed}" == "1" ]]; then
      cp -p "${env_backup}" "${env_path}" || true
    else
      rm -f "${env_path}"
    fi
    rm -f "${manifest_tmp}" "${state_dir}/.brew-env-new.$$"
    fail "could not publish the shared Brew source profile"
  fi
  [[ "${test_mode}" == "1" ]] || chown root:root "${manifest}"
  rm -f "${env_backup}"
}

set_source_profile() {
  local profile="$1"
  require_root
  command -v flock >/dev/null 2>&1 || fail "flock is required"
  [[ -f "${lock_file}" && ! -L "${lock_file}" ]] || fail "shared mutation lock is missing or unsafe"
  exec 9<> "${lock_file}"
  flock -x 9
  set_source_profile_locked "${profile}"
}

ensure_shared_brew() {
  local mirror_profile="$1" target_user legacy_owner="" existing_claim=0
  require_root
  case "${mirror_profile}" in upstream|cn) ;; *) fail "invalid mirror profile" ;; esac
  target_user="$(invoking_user)"
  if [[ -e "${manifest}" || -L "${manifest}" ]]; then
    existing_claim=1
  elif [[ -e "${prefix}" || -L "${prefix}" ]]; then
    validate_legacy_prefix >/dev/null
  fi
  ensure_accounts
  if [[ "${existing_claim}" == "1" ]]; then
    validate_existing_manifest
  fi
  prepare_state_layout
  validate_policy_targets
  command -v flock >/dev/null 2>&1 || fail "flock is required"
  exec 9<> "${lock_file}"
  flock -x 9

  if [[ -e "${manifest}" || -L "${manifest}" ]]; then
    validate_existing_manifest
  else
    initialize_shared_state "${mirror_profile}"
  fi

  install_policy
  enroll_user "${target_user}"
  if [[ -f "${state_dir}/.legacy-owner" ]]; then
    legacy_owner="$(tr -d '[:space:]' < "${state_dir}/.legacy-owner")"
    if [[ -n "${legacy_owner}" && "${legacy_owner}" != "${target_user}" ]]; then
      enroll_user "${legacy_owner}"
    fi
    rm -f "${state_dir}/.legacy-owner"
  fi
  recover_legacy_inventory
}

case "${1:-}" in
  ensure)
    [[ "$#" -eq 2 ]] || fail "usage: ensure PROFILE"
    ensure_shared_brew "$2"
    ;;
  source-profile)
    [[ "$#" -eq 2 ]] || fail "usage: source-profile PROFILE"
    set_source_profile "$2"
    ;;
  *)
    fail "unsupported operation"
    ;;
esac
