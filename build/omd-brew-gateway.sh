#!/usr/bin/env bash
set -euo pipefail

production_libexec="/usr/local/libexec/oh-my-devpod"
production_gateway="${production_libexec}/brew-gateway"
resolved_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
if command -v readlink >/dev/null 2>&1; then
  resolved_self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${resolved_self}")"
fi

if [[ "${resolved_self}" == "${production_gateway}" ||
  "${resolved_self}" == "${production_libexec}/bin/brew" ||
  "${resolved_self}" == "/usr/local/bin/brew" ]]; then
  test_mode=0
  prefix="/home/linuxbrew/.linuxbrew"
  state_dir="/var/lib/oh-my-devpod/linuxbrew"
  libexec_dir="${production_libexec}"
else
  test_mode="${OHMYDEVPOD_SHARED_BREW_TEST_MODE:-0}"
  prefix="${OHMYDEVPOD_SHARED_BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  state_dir="${OHMYDEVPOD_SHARED_BREW_STATE_DIR:-/var/lib/oh-my-devpod/linuxbrew}"
  libexec_dir="${OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR:-${production_libexec}}"
fi

manifest="${state_dir}/manifest"
inventory_dir="${state_dir}/inventory"
real_brew="${prefix}/bin/brew"
stable_gateway="${libexec_dir}/brew-gateway"
lock_file="${state_dir}/locks/mutation.lock"
brew_noninteractive=0
declare -a forwarded_env=()

fail() {
  printf 'brew: shared Linuxbrew gateway: %s\n' "$*" >&2
  exit 1
}

manifest_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "${manifest}" | head -n 1
}

group_gid() {
  local group="$1"
  if command -v getent >/dev/null 2>&1; then
    getent group "${group}" | awk -F: '{print $3}'
  else
    id -g "${group}"
  fi
}

stat_uid() {
  if stat -c '%u' "$1" >/dev/null 2>&1; then stat -c '%u' "$1"; else stat -f '%u' "$1"; fi
}

stat_gid() {
  if stat -c '%g' "$1" >/dev/null 2>&1; then stat -c '%g' "$1"; else stat -f '%g' "$1"; fi
}

stat_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}

validate_manifest() {
  local service_user manager_group expected_uid expected_gid actual_uid actual_gid installation_id
  local schema resolved_prefix recorded_resolved_prefix
  [[ -f "${manifest}" && ! -L "${manifest}" ]] || fail "missing or unsafe shared manifest"
  schema="$(manifest_value schema_version || true)"
  case "${schema}" in 1|2) ;; *) fail "unsupported shared manifest schema" ;; esac
  [[ "$(manifest_value managed_by || true)" == "oh-my-devpod" ]] || fail "shared manifest ownership mismatch"
  [[ "$(manifest_value mode || true)" == "shared-service-account" ]] || fail "shared manifest mode mismatch"
  [[ "$(manifest_value prefix || true)" == "${prefix}" ]] || fail "shared prefix mismatch"
  [[ -d "${prefix}" && ! -L "${prefix}" && -x "${real_brew}" ]] || fail "real Brew backend is unavailable"
  resolved_prefix="$(cd "${prefix}" 2>/dev/null && pwd -P)" || fail "shared prefix cannot be resolved"
  if [[ "${schema}" == "1" ]]; then
    recorded_resolved_prefix="${prefix}"
  else
    recorded_resolved_prefix="$(manifest_value resolved_prefix || true)"
  fi
  [[ "${resolved_prefix}" == "${recorded_resolved_prefix}" ]] || fail "shared resolved prefix mismatch"
  [[ "$(cd "${state_dir}" 2>/dev/null && pwd -P)" == "${state_dir}" ]] || fail "shared state resolves outside its fixed path"
  [[ -d "${inventory_dir}" && ! -L "${inventory_dir}" ]] || fail "shared inventory is unavailable"
  [[ -f "${lock_file}" && ! -L "${lock_file}" ]] || fail "shared mutation lock is unavailable"

  service_user="$(manifest_value service_user || true)"
  manager_group="$(manifest_value manager_group || true)"
  expected_uid="$(manifest_value service_uid || true)"
  expected_gid="$(manifest_value service_gid || true)"
  installation_id="$(manifest_value installation_id || true)"
  [[ "${service_user}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || fail "shared service user is invalid"
  [[ "${manager_group}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || fail "shared manager group is invalid"
  [[ "${expected_uid}" =~ ^[0-9]+$ && "${expected_gid}" =~ ^[0-9]+$ ]] || fail "shared service identity is invalid"
  [[ "${installation_id}" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || fail "shared installation ID is invalid"
  actual_uid="$(id -u "${service_user}" 2>/dev/null || true)"
  if [[ "${test_mode}" == "1" && -n "${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID:-}" ]]; then
    actual_gid="${OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID}"
  else
    actual_gid="$(group_gid "${manager_group}" 2>/dev/null || true)"
  fi
  [[ "${actual_uid}" == "${expected_uid}" && "${actual_gid}" == "${expected_gid}" ]] || fail "shared service identity changed"
  [[ "$(stat_uid "${prefix}")" == "${expected_uid}" && "$(stat_gid "${prefix}")" == "${expected_gid}" ]] || fail "shared prefix ownership changed"
  if [[ "${test_mode}" != "1" ]]; then
    [[ "$(stat_uid "${manifest}")" == "0" && "$(stat_gid "${manifest}")" == "0" ]] || fail "shared manifest is not root-owned"
    (( (8#$(stat_mode "${manifest}") & 8#022) == 0 )) || fail "shared manifest is writable by non-root users"
    [[ "$(stat_uid "${state_dir}")" == "0" && "$(stat_uid "$(dirname "${lock_file}")")" == "0" ]] || fail "shared state parents are not root-owned"
    [[ "$(stat_uid "${stable_gateway}")" == "0" && "$(stat_gid "${stable_gateway}")" == "0" ]] || fail "Brew gateway is not root-owned"
  fi
}

service_user() {
  manifest_value service_user
}

service_home() {
  local user="$1" home=""
  if command -v getent >/dev/null 2>&1; then
    home="$(getent passwd "${user}" 2>/dev/null | awk -F: '{print $6}')"
  fi
  printf '%s\n' "${home:-${state_dir}/service-home}"
}

valid_formula_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9@+_.-]*$ ]]
}

record_value() {
  local record="$1" key="$2"
  sed -n "s/^${key}=//p" "${record}" | head -n 1
}

validate_inventory_records() {
  local record formula installation_id state
  installation_id="$(manifest_value installation_id)"
  for record in "${inventory_dir}"/*; do
    [[ -e "${record}" || -L "${record}" ]] || continue
    [[ -f "${record}" && ! -L "${record}" ]] || fail "unsafe shared inventory record"
    formula="$(basename "${record}")"
    valid_formula_name "${formula}" || fail "invalid formula inventory name"
    [[ "$(record_value "${record}" managed_by || true)" == "oh-my-devpod" ]] || fail "invalid formula inventory owner"
    [[ "$(record_value "${record}" component || true)" == "${formula}" ]] || fail "invalid formula inventory component"
    [[ "$(record_value "${record}" kind || true)" == "brew-formula" ]] || fail "invalid formula inventory kind"
    [[ "$(record_value "${record}" artifact || true)" == "${formula}" ]] || fail "invalid formula inventory artifact"
    [[ "$(record_value "${record}" brew_prefix || true)" == "${prefix}" ]] || fail "invalid formula inventory prefix"
    [[ "$(record_value "${record}" installation_id || true)" == "${installation_id}" ]] || fail "invalid formula inventory installation ID"
    state="$(record_value "${record}" state || true)"
    [[ "${state}" == "managed" || "${state}" == "external" ]] || fail "invalid formula inventory state"
  done
}

is_inventory_mutation() {
  case "${1:-}" in
    ""|--cellar|--config|--env|--prefix|--repository|--version|-v|analytics|autoremove|command|commands|config|deps|desc|doctor|formulae|help|home|info|leaves|list|log|outdated|readall|search|shellenv|tap-info|tap-pin|tap-unpin|uses)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

snapshot_formulae() {
  local destination="$1"
  : > "${destination}"
  [[ -d "${prefix}/Cellar" ]] || return 0
  find "${prefix}/Cellar" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort -u > "${destination}"
}

write_formula_record() {
  local formula="$1" installation_id="$2" state="$3" provenance="$4" record temporary
  valid_formula_name "${formula}" || return 0
  record="${inventory_dir}/${formula}"
  [[ ! -L "${record}" ]] || fail "unsafe formula inventory record"
  temporary="${inventory_dir}/.${formula}.tmp.$$"
  {
    printf 'managed_by=oh-my-devpod\n'
    printf 'component=%s\n' "${formula}"
    printf 'kind=brew-formula\n'
    printf 'artifact=%s\n' "${formula}"
    printf 'brew_prefix=%s\n' "${prefix}"
    printf 'installation_id=%s\n' "${installation_id}"
    printf 'state=%s\n' "${state}"
    printf 'provenance=%s\n' "${provenance}"
    printf 'observed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${temporary}"
  chmod 0644 "${temporary}"
  mv -f "${temporary}" "${record}"
}

reconcile_inventory() {
  local before="$1" installation_id formula record
  installation_id="$(manifest_value installation_id)"
  if [[ -d "${prefix}/Cellar" ]]; then
    while IFS= read -r formula; do
      [[ -n "${formula}" ]] || continue
      record="${inventory_dir}/${formula}"
      if [[ -f "${record}" && ! -L "${record}" ]]; then
        continue
      fi
      if grep -Fqx "${formula}" "${before}" 2>/dev/null; then
        write_formula_record "${formula}" "${installation_id}" external preexisting
      else
        write_formula_record "${formula}" "${installation_id}" managed brew-gateway
      fi
    done < <(find "${prefix}/Cellar" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort -u)
  fi

  for record in "${inventory_dir}"/*; do
    [[ -f "${record}" && ! -L "${record}" ]] || continue
    formula="$(basename "${record}")"
    valid_formula_name "${formula}" || continue
    [[ -d "${prefix}/Cellar/${formula}" ]] || rm -f "${record}"
  done
}

append_gateway_shellenv() {
  local shell_name="${2:-}"
  case "${shell_name}" in
    fish)
      printf 'set -gx PATH %q $PATH;\n' "${libexec_dir}/bin"
      ;;
    csh|tcsh)
      printf 'setenv PATH %q:$PATH;\n' "${libexec_dir}/bin"
      ;;
    *)
      printf 'export PATH=%q:"$PATH"\n' "${libexec_dir}/bin"
      ;;
  esac
}

run_real_brew() {
  local home="$1"
  shift
  local -a clean_env
  clean_env=(HOME="${home}" USER="$(service_user)" LOGNAME="$(service_user)" PATH="/usr/local/bin:/usr/bin:/bin:${prefix}/bin")
  if [[ "${test_mode}" == "1" ]]; then
    clean_env+=(OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OMD_TEST_BREW_LOG="${OMD_TEST_BREW_LOG:-/dev/null}")
  fi
  if [[ "${brew_noninteractive}" == "1" ]]; then
    clean_env+=(NONINTERACTIVE=1 HOMEBREW_NO_ASK=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1)
  fi
  if [[ "${#forwarded_env[@]}" -gt 0 ]]; then
    clean_env+=("${forwarded_env[@]}")
  fi
  [[ -z "${HOMEBREW_NO_AUTO_UPDATE:-}" ]] || clean_env+=(HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE}")
  [[ -z "${HOMEBREW_NO_ANALYTICS:-}" ]] || clean_env+=(HOMEBREW_NO_ANALYTICS="${HOMEBREW_NO_ANALYTICS}")
  [[ -z "${HOMEBREW_NO_ENV_HINTS:-}" ]] || clean_env+=(HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS}")
  env -i "${clean_env[@]}" "${real_brew}" "$@"
}

prepare_backend_working_directory() {
  local fallback="$1" current=""
  current="$(pwd -P 2>/dev/null || true)"
  if [[ -n "${current}" && -r "${current}" && -x "${current}" ]]; then
    return 0
  fi
  cd -P "${fallback}" 2>/dev/null || fail "service home is not an accessible working directory"
}

run_backend() {
  local home status mutates=0 before name value
  if [[ "${1:-}" == "--omd-forwarded" ]]; then
    shift
    while [[ "${1:-}" != "--" ]]; do
      case "${1:-}" in
        --omd-noninteractive)
          brew_noninteractive=1
          shift
          ;;
        --omd-env)
          [[ "$#" -ge 3 ]] || fail "invalid forwarded Brew environment"
          name="$2"
          value="$3"
          case "${name}" in
            HOMEBREW_NO_AUTO_UPDATE|HOMEBREW_NO_ANALYTICS|HOMEBREW_NO_ENV_HINTS|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy) ;;
            *) fail "unsupported forwarded Brew environment" ;;
          esac
          [[ "${#value}" -le 4096 ]] || fail "forwarded Brew environment is too large"
          forwarded_env+=("${name}=${value}")
          shift 3
          ;;
        *)
          fail "invalid internal gateway arguments"
          ;;
      esac
    done
    [[ "${1:-}" == "--" ]] || fail "invalid internal gateway arguments"
    shift
  fi
  validate_manifest
  [[ "$(id -u)" == "$(manifest_value service_uid)" ]] || fail "backend must run as $(service_user)"
  validate_inventory_records
  home="$(service_home "$(service_user)")"
  prepare_backend_working_directory "${home}"
  before="${state_dir}/.inventory-before.$$"
  if is_inventory_mutation "${1:-}"; then
    mutates=1
    snapshot_formulae "${before}"
  fi

  set +e
  run_real_brew "${home}" "$@"
  status=$?
  set -e
  if [[ "${status}" -eq 0 && "${1:-}" == "shellenv" ]]; then
    append_gateway_shellenv "$@"
  fi
  if [[ "${mutates}" == "1" ]]; then
    reconcile_inventory "${before}"
    rm -f "${before}"
  fi
  return "${status}"
}

run_locked_backend() {
  command -v flock >/dev/null 2>&1 || fail "flock is required"
  exec 9<> "${lock_file}"
  flock -x 9
  run_backend "$@"
}

validate_manifest
if [[ "${1:-}" == "--service" ]]; then
  shift
  run_locked_backend "$@"
  exit $?
fi

expected_user="$(service_user)"
if [[ "$(id -u)" == "$(manifest_value service_uid)" ]]; then
  run_locked_backend "$@"
  exit $?
fi
declare -a forwarded_args
forwarded_args=(--omd-forwarded)
if [[ "${OHMYDEVPOD_BREW_NONINTERACTIVE:-0}" == "1" ]]; then
  forwarded_args+=(--omd-noninteractive)
fi
for name in HOMEBREW_NO_AUTO_UPDATE HOMEBREW_NO_ANALYTICS HOMEBREW_NO_ENV_HINTS HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
  if [[ -n "${!name:-}" ]]; then
    forwarded_args+=(--omd-env "${name}" "${!name}")
  fi
done
forwarded_args+=(--)
exec sudo -n -H -u "${expected_user}" -- "${stable_gateway}" --service "${forwarded_args[@]}" "$@"
