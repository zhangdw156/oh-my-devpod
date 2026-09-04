#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
tmp_dir="$(cd "${tmp_dir}" && pwd -P)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1" expected="$2"
  grep -Fqx -- "${expected}" "${file}" || fail "${file} should contain: ${expected}"
}

fake_bin="${tmp_dir}/fake-bin"
fake_brew_source="${tmp_dir}/fake-real-brew"
brew_log="${tmp_dir}/brew.log"
service_user="$(id -un)"
manager_group="$(id -gn)"
service_uid="$(id -u)"
service_gid="$(id -g)"
mkdir -p "${fake_bin}"
: > "${brew_log}"

cat > "${fake_bin}/flock" <<'FLOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "-x" && "${2:-}" == "9" ]]
FLOCK
chmod +x "${fake_bin}/flock"

cat > "${fake_brew_source}" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail

prefix="${OHMYDEVPOD_SHARED_BREW_PREFIX}"
printf '<%s>' "$@" >> "${OMD_TEST_BREW_LOG}"
printf '\n' >> "${OMD_TEST_BREW_LOG}"
printf '[no_analytics=%s]\n' "${HOMEBREW_NO_ANALYTICS:-}" >> "${OMD_TEST_BREW_LOG}"
printf '[cwd=%s]\n' "$(pwd -P)" >> "${OMD_TEST_BREW_LOG}"
case "${1:-}" in
  --prefix)
    printf '%s\n' "${prefix}"
    ;;
  shellenv)
    printf 'export HOMEBREW_PREFIX=%q\n' "${prefix}"
    printf 'export PATH=%q:"$PATH"\n' "${prefix}/bin"
    ;;
  install)
    mkdir -p "${prefix}/Cellar/${2}/1.0"
    ;;
  upgrade)
    [[ -d "${prefix}/Cellar/${2}" ]]
    : > "${prefix}/Cellar/${2}/upgraded"
    ;;
  uninstall)
    rm -rf "${prefix}/Cellar/${2}"
    ;;
  list)
    find "${prefix}/Cellar" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || true
    ;;
  *)
    ;;
esac
BREW
chmod +x "${fake_brew_source}"

run_provision() {
  local prefix="$1" state_dir="$2" libexec_dir="$3" sudoers_file="$4" target_user="$5" target_home="$6"
  env PATH="${fake_bin}:${PATH}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_SUDOERS_FILE="${sudoers_file}" OHMYDEVPOD_SHARED_BREW_SERVICE_USER="${service_user}" OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP="${manager_group}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_ROOT="${tmp_dir}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_TARGET_USER="${target_user}" OHMYDEVPOD_SHARED_BREW_TEST_TARGET_HOME="${target_home}" OHMYDEVPOD_SHARED_BREW_TEST_REAL_BIN="${fake_brew_source}" OMD_TEST_BREW_LOG="${brew_log}" bash -c 'set -euo pipefail; source "$1/modules/lib/shared-linuxbrew.sh"; omd_shared_linuxbrew_provision "$1" upstream' _ "${repo_root}"
}

run_gateway() {
  local prefix="$1" state_dir="$2" libexec_dir="$3" home="$4"
  shift 4
  env PATH="${fake_bin}:${PATH}" HOME="${home}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_SERVICE_USER="${service_user}" OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP="${manager_group}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OMD_TEST_BREW_LOG="${brew_log}" "${libexec_dir}/bin/brew" "$@"
}

run_set_profile() {
  local prefix="$1" state_dir="$2" libexec_dir="$3" profile="$4"
  env PATH="${fake_bin}:${PATH}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_SERVICE_USER="${service_user}" OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP="${manager_group}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OMD_TEST_BREW_LOG="${brew_log}" bash -c 'set -euo pipefail; source "$1/modules/lib/shared-linuxbrew.sh"; omd_shared_linuxbrew_set_profile "$2"' _ "${repo_root}" "${profile}"
}

prefix="${tmp_dir}/fresh/home/linuxbrew/.linuxbrew"
state_dir="${tmp_dir}/fresh/var/lib/oh-my-devpod/linuxbrew"
libexec_dir="${tmp_dir}/fresh/usr/local/libexec/oh-my-devpod"
sudoers_file="${tmp_dir}/fresh/etc/sudoers.d/oh-my-devpod-brew"
user_a_home="${tmp_dir}/fresh/home/user-a"
user_b_home="${tmp_dir}/fresh/home/user-b"
mkdir -p "${user_a_home}" "${user_b_home}" "$(dirname "${sudoers_file}")"

run_provision "${prefix}" "${state_dir}" "${libexec_dir}" "${sudoers_file}" user-a "${user_a_home}"

gateway="${libexec_dir}/bin/brew"
profile_file="${state_dir}/profile.d/oh-my-devpod-brew.sh"
[[ -x "${gateway}" ]] || fail "provisioner should install the Brew gateway"
[[ -L "${libexec_dir}/global-bin/brew" ]] || fail "provisioner should install a global Brew command shim"
[[ -f "${profile_file}" ]] || fail "provisioner should install login-shell gateway activation"
[[ -x "${prefix}/bin/brew" ]] || fail "provisioner should install the real Brew backend"
assert_file_contains "${state_dir}/manifest" "prefix=${prefix}"
assert_file_contains "${state_dir}/manifest" "schema_version=2"
assert_file_contains "${state_dir}/manifest" "resolved_prefix=${prefix}"
assert_file_contains "${state_dir}/manifest" "service_user=${service_user}"
assert_file_contains "${state_dir}/manifest" "service_uid=${service_uid}"
assert_file_contains "${state_dir}/manifest" "service_gid=${service_gid}"
[[ -f "${state_dir}/members/user-a" ]] || fail "user A should be enrolled"
assert_file_contains "${sudoers_file}" "%${manager_group} ALL=(${service_user}) NOPASSWD: ${libexec_dir}/brew-gateway --service *"

login_path="$(
  env PATH="/usr/bin:/bin" bash --noprofile --norc -c \
    'source "$1"; printf "%s\n" "$PATH"' _ "${profile_file}"
)"
case ":${login_path}:" in
  ":${libexec_dir}/bin:${prefix}/bin:${prefix}/sbin:"*) ;;
  *) fail "login activation should expose shared formulae behind the Brew gateway: ${login_path}" ;;
esac

run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" install ripgrep
[[ -d "${prefix}/Cellar/ripgrep/1.0" ]] || fail "direct brew install should mutate the shared prefix"
assert_file_contains "${state_dir}/inventory/ripgrep" "state=managed"
assert_file_contains "${state_dir}/inventory/ripgrep" "artifact=ripgrep"
run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" --service --omd-forwarded --omd-env HOMEBREW_NO_ANALYTICS 1 -- info ripgrep
grep -Fqx '[no_analytics=1]' "${brew_log}" || fail "gateway should safely forward supported Brew environment"

readable_cwd="${tmp_dir}/readable-cwd"
private_cwd="${user_a_home}/private-cwd"
mkdir -p "${readable_cwd}" "${private_cwd}"
: > "${brew_log}"
(
  cd "${readable_cwd}"
  run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" --prefix >/dev/null 2>&1
)
grep -Fqx "[cwd=${readable_cwd}]" "${brew_log}" || fail "gateway should preserve a readable working directory"

if command -v getent >/dev/null 2>&1; then
  expected_service_home="$(getent passwd "${service_user}" | awk -F: '{print $6}')"
else
  expected_service_home="${state_dir}/service-home"
fi
: > "${brew_log}"
(
  cd "${private_cwd}"
  chmod 0000 "${private_cwd}"
  set +e
  run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" --prefix >/dev/null 2>&1
  gateway_status=$?
  set -e
  chmod 0700 "${private_cwd}"
  [[ "${gateway_status}" -eq 0 ]]
)
grep -Fqx "[cwd=${expected_service_home}]" "${brew_log}" || fail "gateway should fall back from an unreadable working directory"

if env HOME="${user_b_home}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER=user-b OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_UID="${service_uid}" "${repo_root}/modules/core/linuxbrew.sh" status; then
  fail "an unenrolled user should cause Linuxbrew to be planned for enrollment"
fi

run_provision "${prefix}" "${state_dir}" "${libexec_dir}" "${sudoers_file}" user-b "${user_b_home}"
[[ -f "${state_dir}/members/user-b" ]] || fail "user B should be enrolled"
env HOME="${user_b_home}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER=user-b OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_UID="${service_uid}" "${repo_root}/modules/core/linuxbrew.sh" managed || fail "enrolled user B should manage shared Linuxbrew"

git -C "${prefix}" init -q
git -C "${prefix}" remote add origin https://github.com/Homebrew/brew.git
run_set_profile "${prefix}" "${state_dir}" "${libexec_dir}" cn
assert_file_contains "${state_dir}/manifest" "mirror_profile=cn"
assert_file_contains "${prefix}/etc/homebrew/brew.env" "# Generated by oh-my-devpod. Shared host-scoped Homebrew source configuration."
[[ "$(git -C "${prefix}" remote get-url origin)" == "https://mirrors.ustc.edu.cn/brew.git" ]] || fail "shared source switch should update the Brew remote"
run_set_profile "${prefix}" "${state_dir}" "${libexec_dir}" upstream
assert_file_contains "${state_dir}/manifest" "mirror_profile=upstream"
[[ ! -e "${prefix}/etc/homebrew/brew.env" ]] || fail "upstream profile should remove the managed shared brew.env"

env PATH="${fake_bin}:/usr/bin:/bin" HOME="${user_b_home}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER=user-b OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_UID="${service_uid}" "${repo_root}/modules/tools/ripgrep.sh" managed || fail "user B OMD should see user A's direct Brew install as managed"

run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_b_home}" upgrade ripgrep
[[ -f "${prefix}/Cellar/ripgrep/upgraded" ]] || fail "user B should directly upgrade user A's formula"

injection_target="${tmp_dir}/injected"
run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" info "literal;touch ${injection_target}"
[[ ! -e "${injection_target}" ]] || fail "gateway must not evaluate Brew arguments"
grep -Fq "<literal;touch ${injection_target}>" "${brew_log}" || fail "gateway should preserve Brew argv"

shellenv_output="$(run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" shellenv)"
printf '%s\n' "${shellenv_output}" | grep -Fq "export PATH=${libexec_dir}/bin:" || fail "brew shellenv should keep the gateway before the real Brew bin"

mkdir -p "${prefix}/Cellar/preexisting/1.0"
run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" upgrade preexisting
assert_file_contains "${state_dir}/inventory/preexisting" "state=external"

run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_b_home}" uninstall ripgrep
[[ ! -d "${prefix}/Cellar/ripgrep" ]] || fail "direct brew uninstall should remove the shared formula"
[[ ! -e "${state_dir}/inventory/ripgrep" ]] || fail "direct brew uninstall should reconcile the shared marker"

if env PATH="${fake_bin}:/usr/bin:/bin" HOME="${user_a_home}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${state_dir}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${libexec_dir}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_USER=user-a OHMYDEVPOD_SHARED_BREW_TEST_CURRENT_UID="${service_uid}" "${repo_root}/modules/tools/ripgrep.sh" managed; then
  fail "both OMD installations should observe direct Brew removal"
fi

cp "${state_dir}/inventory/preexisting" "${tmp_dir}/preexisting.record"
sed 's/^installation_id=.*/installation_id=forged/' "${tmp_dir}/preexisting.record" > "${state_dir}/inventory/preexisting"
if run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" info preexisting >/dev/null 2>&1; then
  fail "gateway should reject a forged inventory installation ID"
fi
cp "${tmp_dir}/preexisting.record" "${state_dir}/inventory/preexisting"

cp "${state_dir}/manifest" "${tmp_dir}/manifest"
sed 's/^service_uid=.*/service_uid=999999/' "${tmp_dir}/manifest" > "${state_dir}/manifest"
if run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" info preexisting >/dev/null 2>&1; then
  fail "gateway should reject a forged service UID"
fi
cp "${tmp_dir}/manifest" "${state_dir}/manifest"

sed -e 's/^schema_version=2$/schema_version=1/' -e '/^resolved_prefix=/d' \
  "${state_dir}/manifest" > "${tmp_dir}/schema-1-manifest"
cp "${tmp_dir}/schema-1-manifest" "${state_dir}/manifest"
run_gateway "${prefix}" "${state_dir}" "${libexec_dir}" "${user_a_home}" info preexisting >/dev/null
cp "${tmp_dir}/manifest" "${state_dir}/manifest"

conflict_prefix="${tmp_dir}/conflict/home/linuxbrew/.linuxbrew"
conflict_state="${tmp_dir}/conflict/state"
conflict_libexec="${tmp_dir}/conflict/libexec"
conflict_sudoers="${tmp_dir}/conflict/sudoers"
conflict_home="${tmp_dir}/conflict/home/user"
mkdir -p "${conflict_prefix}/bin" "${conflict_prefix}/Cellar" "${conflict_home}"
install -m 0755 "${fake_brew_source}" "${conflict_prefix}/bin/brew"
if run_provision "${conflict_prefix}" "${conflict_state}" "${conflict_libexec}" "${conflict_sudoers}" user "${conflict_home}" >"${tmp_dir}/conflict.out" 2>&1; then
  fail "an unmarked existing prefix must not be adopted"
fi
grep -Fq 'unmanaged-prefix-conflict' "${tmp_dir}/conflict.out" || fail "unmanaged prefix refusal should be explicit"
[[ ! -e "${conflict_state}/manifest" ]] || fail "unmanaged prefix refusal must not publish a manifest"

legacy_prefix="${tmp_dir}/legacy/home/linuxbrew/.linuxbrew"
legacy_state="${tmp_dir}/legacy/state"
legacy_libexec="${tmp_dir}/legacy/libexec"
legacy_sudoers="${tmp_dir}/legacy/sudoers"
legacy_home="${tmp_dir}/legacy/home/owner"
legacy_user_home="${tmp_dir}/legacy/home/user-b"
legacy_markers="${legacy_home}/.local/state/oh-my-devpod/managed"
mkdir -p "${legacy_prefix}/bin" "${legacy_prefix}/Cellar/ripgrep/1.0" "${legacy_prefix}/Cellar/jq/1.0" "${legacy_markers}" "${legacy_user_home}"
install -m 0755 "${fake_brew_source}" "${legacy_prefix}/bin/brew"
cat > "${legacy_markers}/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${legacy_prefix}
EOF
cat > "${legacy_markers}/ripgrep" <<EOF
managed_by=oh-my-devpod
component=ripgrep
kind=brew-formula
artifact=ripgrep
brew_prefix=${legacy_prefix}
EOF

env PATH="${fake_bin}:${PATH}" OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${legacy_prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${legacy_state}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${legacy_libexec}" OHMYDEVPOD_SHARED_BREW_SUDOERS_FILE="${legacy_sudoers}" OHMYDEVPOD_SHARED_BREW_SERVICE_USER="${service_user}" OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP="${manager_group}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_TARGET_USER=user-b OHMYDEVPOD_SHARED_BREW_TEST_TARGET_HOME="${legacy_user_home}" OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_OWNER="${service_user}" OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME="${legacy_home}" OHMYDEVPOD_SHARED_BREW_TEST_REAL_BIN="${fake_brew_source}" OMD_TEST_BREW_LOG="${brew_log}" bash -c 'set -euo pipefail; source "$1/modules/lib/shared-linuxbrew.sh"; omd_shared_linuxbrew_provision "$1" upstream' _ "${repo_root}"

assert_file_contains "${legacy_state}/inventory/ripgrep" "state=managed"
assert_file_contains "${legacy_state}/inventory/ripgrep" "provenance=legacy-marker"
assert_file_contains "${legacy_state}/inventory/jq" "state=external"
[[ -f "${legacy_state}/members/user-b" ]] || fail "migration should enroll the invoking user"
[[ -f "${legacy_state}/members/${service_user}" ]] || fail "migration should enroll the legacy owner"

unsafe_root="${tmp_dir}/unsafe-link"
unsafe_prefix="${unsafe_root}/home/linuxbrew/.linuxbrew"
unsafe_resolved="${unsafe_root}/storage/linuxbrew/.linuxbrew"
unsafe_state="${unsafe_root}/state"
unsafe_libexec="${unsafe_root}/libexec"
unsafe_sudoers="${unsafe_root}/sudoers"
unsafe_owner_home="${unsafe_root}/owner"
unsafe_user_home="${unsafe_root}/user"
mkdir -p "${unsafe_root}/home" "${unsafe_resolved}/bin" "${unsafe_owner_home}/.local/state/oh-my-devpod/managed" "${unsafe_user_home}"
chmod 0777 "${unsafe_root}/storage"
ln -s "${unsafe_root}/storage/linuxbrew" "${unsafe_root}/home/linuxbrew"
install -m 0755 "${fake_brew_source}" "${unsafe_resolved}/bin/brew"
cat > "${unsafe_owner_home}/.local/state/oh-my-devpod/managed/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${unsafe_prefix}
EOF
if OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_OWNER="${service_user}" \
  OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME="${unsafe_owner_home}" \
  run_provision "${unsafe_prefix}" "${unsafe_state}" "${unsafe_libexec}" "${unsafe_sudoers}" user "${unsafe_user_home}" >"${tmp_dir}/unsafe-link.out" 2>&1; then
  fail "a symlink through user-writable storage must not be adopted"
fi
grep -Fq 'unmanaged-prefix-conflict' "${tmp_dir}/unsafe-link.out" || fail "unsafe storage symlink refusal should be explicit"
[[ ! -e "${unsafe_state}/manifest" ]] || fail "unsafe storage symlink must not publish a manifest"

update_fixture="${tmp_dir}/update-fixture/oh-my-devpod"
update_archive="${tmp_dir}/update-fixture.tar.gz"
update_prefix="${tmp_dir}/update-prefix"
update_bin="${tmp_dir}/update-bin"
update_brew_prefix="${tmp_dir}/update-legacy/home/linuxbrew/.linuxbrew"
update_brew_state="${tmp_dir}/update-legacy/state"
update_brew_libexec="${tmp_dir}/update-legacy/libexec"
update_brew_sudoers="${tmp_dir}/update-legacy/sudoers"
update_owner_home="${tmp_dir}/update-legacy/home/owner"
update_user_home="${tmp_dir}/update-legacy/home/user"
update_second_user_home="${tmp_dir}/update-legacy/home/user-b"
update_brew_resolved="${tmp_dir}/update-legacy/data/linuxbrew/.linuxbrew"
mkdir -p "${update_fixture}/bin" "${update_fixture}/install" "${update_fixture}/modules/lib" "${update_fixture}/build" "${update_fixture}/config" "${update_fixture}/vendor" "${tmp_dir}/update-legacy/home" "${update_brew_resolved}/bin" "${update_owner_home}/.local/state/oh-my-devpod/managed" "${update_user_home}" "${update_second_user_home}"
chmod 0775 "${tmp_dir}/update-legacy/data" "${tmp_dir}/update-legacy/data/linuxbrew"
ln -s "${tmp_dir}/update-legacy/data/linuxbrew" "${tmp_dir}/update-legacy/home/linuxbrew"
printf '#!/usr/bin/env bash\nprintf "updated omd\\n"\n' > "${update_fixture}/bin/omd"
chmod +x "${update_fixture}/bin/omd"
cp "${repo_root}/install/bootstrap.sh" "${update_fixture}/install/bootstrap.sh"
cp "${repo_root}/install/update.sh" "${update_fixture}/install/update.sh"
cp "${repo_root}/modules/lib/shared-linuxbrew.sh" "${update_fixture}/modules/lib/shared-linuxbrew.sh"
cp "${repo_root}/build/omd-brew-gateway.sh" "${update_fixture}/build/omd-brew-gateway.sh"
cp "${repo_root}/build/omd-brew-provisioner.sh" "${update_fixture}/build/omd-brew-provisioner.sh"
printf 'schema_version = 1\n' > "${update_fixture}/components.toml"
printf '9.9.0\n' > "${update_fixture}/VERSION"
printf 'TEST=1\n' > "${update_fixture}/versions.env"
install -m 0755 "${fake_brew_source}" "${update_brew_prefix}/bin/brew"
cat > "${update_owner_home}/.local/state/oh-my-devpod/managed/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${update_brew_prefix}
EOF
tar -czf "${update_archive}" -C "${tmp_dir}/update-fixture" oh-my-devpod
installed_version="$(env PATH="${fake_bin}:${PATH}" OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1 OHMYDEVPOD_SHARED_BREW_TEST_MODE=1 OHMYDEVPOD_SHARED_BREW_PREFIX="${update_brew_prefix}" OHMYDEVPOD_SHARED_BREW_STATE_DIR="${update_brew_state}" OHMYDEVPOD_SHARED_BREW_LIBEXEC_DIR="${update_brew_libexec}" OHMYDEVPOD_SHARED_BREW_SUDOERS_FILE="${update_brew_sudoers}" OHMYDEVPOD_SHARED_BREW_SERVICE_USER="${service_user}" OHMYDEVPOD_SHARED_BREW_MANAGER_GROUP="${manager_group}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_SERVICE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_ROOT="${tmp_dir}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_UID="${service_uid}" OHMYDEVPOD_SHARED_BREW_TEST_TRUSTED_STORAGE_GID="${service_gid}" OHMYDEVPOD_SHARED_BREW_TEST_TARGET_USER=update-user OHMYDEVPOD_SHARED_BREW_TEST_TARGET_HOME="${update_user_home}" OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_OWNER="${service_user}" OHMYDEVPOD_SHARED_BREW_TEST_LEGACY_HOME="${update_owner_home}" OHMYDEVPOD_SHARED_BREW_TEST_REAL_BIN="${fake_brew_source}" OMD_TEST_BREW_LOG="${brew_log}" bash -c 'set -euo pipefail; source "$1/install/bootstrap.sh"; omd_install_archive "$2" "$3" "$4"' _ "${repo_root}" "${update_archive}" "${update_prefix}" "${update_bin}")"
[[ "${installed_version}" == "9.9.0" ]] || fail "candidate release activation should preserve the installed version output"
[[ -f "${update_brew_state}/manifest" ]] || fail "candidate release installation should migrate legacy Linuxbrew before success"
assert_file_contains "${update_brew_state}/manifest" "prefix=${update_brew_prefix}"
assert_file_contains "${update_brew_state}/manifest" "resolved_prefix=${update_brew_resolved}"
[[ -L "${update_bin}/omd" ]] || fail "candidate release should activate omd after shared Brew migration"

run_provision "${update_brew_prefix}" "${update_brew_state}" "${update_brew_libexec}" "${update_brew_sudoers}" user-b "${update_second_user_home}"
[[ -f "${update_brew_state}/members/user-b" ]] || fail "a second user should join Linuxbrew through the trusted storage symlink"
run_gateway "${update_brew_prefix}" "${update_brew_state}" "${update_brew_libexec}" "${update_second_user_home}" info ripgrep >/dev/null

alternate_brew_resolved="${tmp_dir}/update-legacy/data/alternate/.linuxbrew"
mkdir -p "${alternate_brew_resolved}/bin"
install -m 0755 "${fake_brew_source}" "${alternate_brew_resolved}/bin/brew"
rm -- "${tmp_dir}/update-legacy/home/linuxbrew"
ln -s "${tmp_dir}/update-legacy/data/alternate" "${tmp_dir}/update-legacy/home/linuxbrew"
if run_gateway "${update_brew_prefix}" "${update_brew_state}" "${update_brew_libexec}" "${update_user_home}" info ripgrep >"${tmp_dir}/retarget.out" 2>&1; then
  fail "the gateway must reject a trusted symlink retargeted after migration"
fi
grep -Fq 'shared resolved prefix mismatch' "${tmp_dir}/retarget.out" || fail "symlink retarget refusal should identify the resolved-prefix mismatch"

printf 'shared Linuxbrew tests passed\n'
