#!/usr/bin/env bash
set -euo pipefail

unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap="${repo_root}/install/bootstrap.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" path="$2"
  grep -Fq "${needle}" "${path}" || fail "expected '${needle}' in ${path}"
}

assert_absent() {
  local needle="$1" path="$2"
  if grep -Fq "${needle}" "${path}" 2>/dev/null; then
    fail "did not expect '${needle}' in ${path}"
  fi
}

assert_equal() {
  local expected="$1" actual="$2" message="$3"
  [[ "${expected}" == "${actual}" ]] || fail "${message}: expected '${expected}', got '${actual}'"
}

(cd "${repo_root}" && cargo build --quiet -p omd)
omd_binary="${repo_root}/target/debug/omd"

make_bundle() {
  local version="$1" output_dir="$2" payload_root archive
  payload_root="${output_dir}/payload/oh-my-devpod"
  mkdir -p \
    "${payload_root}/bin" \
    "${payload_root}/install" \
    "${payload_root}/modules/lib" \
    "${payload_root}/modules/tools" \
    "${payload_root}/build" \
    "${payload_root}/config" \
    "${payload_root}/vendor"
  install -m 0755 "${omd_binary}" "${payload_root}/bin/omd"
  install -m 0755 "${repo_root}/install/bootstrap.sh" "${payload_root}/install/bootstrap.sh"
  install -m 0755 "${repo_root}/install/update.sh" "${payload_root}/install/update.sh"
  install -m 0755 "${repo_root}/modules/lib/common.sh" "${payload_root}/modules/lib/common.sh"
  install -m 0755 "${repo_root}/modules/lib/shared-linuxbrew.sh" "${payload_root}/modules/lib/shared-linuxbrew.sh"
  install -m 0755 "${repo_root}/modules/lib/postflight.sh" "${payload_root}/modules/lib/postflight.sh"
  install -m 0755 "${repo_root}/modules/lib/source-config.sh" "${payload_root}/modules/lib/source-config.sh"
  install -m 0755 "${repo_root}/build/omd-brew-gateway.sh" "${payload_root}/build/omd-brew-gateway.sh"
  install -m 0755 "${repo_root}/build/omd-brew-provisioner.sh" "${payload_root}/build/omd-brew-provisioner.sh"
  cat > "${payload_root}/components.toml" <<'EOF'
schema_version = 1

[[component]]
id = "probe"
name = "Probe"
description = "Source environment probe"
category = "terminal"
module = "modules/tools/probe.sh"
requires = []
install_requires = []
uninstall = true
EOF
  cat > "${payload_root}/modules/tools/probe.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  status|managed) exit 1 ;;
  install|update)
    {
      printf 'profile=%s\n' "${OHMYDEVPOD_MIRROR_PROFILE:-}"
      printf 'brew_git=%s\n' "${HOMEBREW_BREW_GIT_REMOTE:-}"
      printf 'brew_core=%s\n' "${HOMEBREW_CORE_GIT_REMOTE:-}"
      printf 'brew_bottle=%s\n' "${HOMEBREW_BOTTLE_DOMAIN:-}"
      printf 'brew_api=%s\n' "${HOMEBREW_API_DOMAIN:-}"
      printf 'uv_config=%s\n' "${UV_CONFIG_FILE:-}"
      printf 'pip_index=%s\n' "${PIP_INDEX_URL:-}"
      printf 'conda_channels=%s\n' "${CONDA_CHANNELS:-}"
      printf 'mamba_channel_alias=%s\n' "${MAMBA_CHANNEL_ALIAS:-}"
      printf 'mamba_default_channels=%s\n' "${MAMBA_DEFAULT_CHANNELS:-}"
    } > "${OHMYDEVPOD_TEST_COMPONENT_LOG}"
    ;;
  uninstall) exit 0 ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "${payload_root}/modules/tools/probe.sh"
  printf '%s\n' "${version}" > "${payload_root}/VERSION"
  printf 'TEST_VERSION=1\n' > "${payload_root}/versions.env"
  printf 'build fixture\n' > "${payload_root}/build/marker"
  printf 'config fixture\n' > "${payload_root}/config/marker"
  printf 'vendor fixture\n' > "${payload_root}/vendor/marker"

  archive="${output_dir}/omd-x86_64-unknown-linux-gnu.tar.gz"
  tar -czf "${archive}" -C "${output_dir}/payload" oh-my-devpod
  (
    cd "${output_dir}"
    sha256sum "$(basename "${archive}")" > "$(basename "${archive}").sha256"
  )
}

mkdir -p "${tmp_dir}/release-1.2.3" "${tmp_dir}/release-1.2.4"
make_bundle "1.2.3" "${tmp_dir}/release-1.2.3"
make_bundle "1.2.4" "${tmp_dir}/release-1.2.4"
archive_123="${tmp_dir}/release-1.2.3/omd-x86_64-unknown-linux-gnu.tar.gz"
checksum_123="${archive_123}.sha256"
archive_124="${tmp_dir}/release-1.2.4/omd-x86_64-unknown-linux-gnu.tar.gz"
checksum_124="${archive_124}.sha256"

fake_bin="${tmp_dir}/fake-bin"
mkdir -p "${fake_bin}"
real_mv="$(command -v mv)"
real_id="$(command -v id)"
cat > "${fake_bin}/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'x86_64\n' ;;
  *) printf 'Linux\n' ;;
esac
EOF
cat > "${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

destination=""
url=""
while (($#)); do
  case "$1" in
    -o|--output)
      destination="$2"
      shift 2
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done
printf '%s\n' "${url}" >> "${OHMYDEVPOD_TEST_CURL_LOG}"

if [[ "${url}" == */releases/latest ]]; then
  printf '{"tag_name":"v%s"}\n' "${OHMYDEVPOD_TEST_LATEST_VERSION}"
  exit 0
fi
if [[ "${OHMYDEVPOD_TEST_DOWNLOAD_FAIL:-0}" == "1" && "${url}" != *.sha256 ]]; then
  exit 22
fi

source_file="${OHMYDEVPOD_TEST_ARCHIVE}"
if [[ "${url}" == *.sha256 ]]; then
  source_file="${OHMYDEVPOD_TEST_CHECKSUM}"
fi
if [[ -n "${destination}" ]]; then
  cp "${source_file}" "${destination}"
else
  cat "${source_file}"
fi
EOF
cat > "${fake_bin}/mv" <<EOF
#!/usr/bin/env bash
set -euo pipefail
destination="\${!#}"
if [[ "\${OHMYDEVPOD_TEST_FAIL_ACTIVATION:-0}" == "1" && "\${destination}" == */bin/omd ]]; then
  exit 1
fi
exec "${real_mv}" "\$@"
EOF
cat > "${fake_bin}/id" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  -u)
    [[ -z "\${OMD_TEST_ID_UID:-}" ]] || { printf '%s\n' "\${OMD_TEST_ID_UID}"; exit 0; }
    ;;
  -un)
    [[ -z "\${OMD_TEST_ID_USER:-}" ]] || { printf '%s\n' "\${OMD_TEST_ID_USER}"; exit 0; }
    ;;
esac
exec "${real_id}" "\$@"
EOF
cat > "${fake_bin}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${OMD_TEST_SUDO_LOG}"
case "${1:-}" in
  tee)
    shift
    exec tee "$@"
    ;;
  chsh) exit 0 ;;
  *) exit 2 ;;
esac
EOF
cat > "${fake_bin}/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x \
  "${fake_bin}/uname" \
  "${fake_bin}/curl" \
  "${fake_bin}/mv" \
  "${fake_bin}/id" \
  "${fake_bin}/sudo" \
  "${fake_bin}/zsh"

ubuntu_release="${tmp_dir}/ubuntu-os-release"
cat > "${ubuntu_release}" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
EOF

install_fixture() {
  local source="$1" home="$2"
  mkdir -p "${home}"
  PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME="${home}" \
    OHMYDEVPOD_OS_RELEASE="${ubuntu_release}" \
    OHMYDEVPOD_SOURCE="${source}" \
    OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
    OHMYDEVPOD_OMD_ARCHIVE="${archive_123}" \
    OHMYDEVPOD_OMD_CHECKSUM="${checksum_123}" \
    bash "${bootstrap}" >/dev/null
}

run_update() {
  local home="$1" log="$2"
  shift 2
  : > "${log}"
  PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME="${home}" \
    OHMYDEVPOD_TEST_ARCHIVE="${archive_124}" \
    OHMYDEVPOD_TEST_CHECKSUM="${checksum_124}" \
    OHMYDEVPOD_TEST_CURL_LOG="${log}" \
    OHMYDEVPOD_TEST_LATEST_VERSION="1.2.4" \
    "${home}/.local/bin/omd" --update "$@"
}

assert_source_profile() {
  local home="$1" source="$2" profile="$3"
  assert_equal "${source}" "$(cat "${home}/.config/oh-my-devpod/source")" "saved source"
  assert_equal "${profile}" "$(cat "${home}/.config/oh-my-devpod/mirror-profile")" "mirror profile"
}

default_home="${tmp_dir}/default-home"
default_log="${tmp_dir}/default.log"
default_output="${tmp_dir}/default.out"
install_fixture github "${default_home}"
rm -f "${default_home}/.config/oh-my-devpod/source"
run_update "${default_home}" "${default_log}" > "${default_output}"
assert_contains 'api.github.com' "${default_log}"
assert_absent 'gitee.com' "${default_log}"
[[ ! -e "${default_home}/.config/oh-my-devpod/source" ]] ||
  fail "implicit update should not rewrite a missing source configuration"
assert_equal \
  upstream \
  "$(cat "${default_home}/.config/oh-my-devpod/mirror-profile")" \
  "default mirror profile"
assert_equal 'omd 1.2.4' "$("${default_home}/.local/bin/omd" --version)" "updated version"
assert_contains 'Current version: 1.2.3' "${default_output}"
assert_contains 'Current source: github' "${default_output}"
assert_contains 'Update source: github' "${default_output}"
assert_contains 'Latest version: 1.2.4' "${default_output}"
assert_contains 'Successfully updated omd to 1.2.4' "${default_output}"

candidate_bootstrap_home="${tmp_dir}/candidate-bootstrap-home"
candidate_bootstrap_log="${tmp_dir}/candidate-bootstrap.log"
candidate_bootstrap_output="${tmp_dir}/candidate-bootstrap.out"
install_fixture github "${candidate_bootstrap_home}"
cat >> \
  "${candidate_bootstrap_home}/.local/share/oh-my-devpod/releases/1.2.3/install/bootstrap.sh" <<'EOF'

omd_install_archive() {
  printf 'the active release bootstrap must not install its replacement\n' >&2
  return 97
}
EOF
run_update \
  "${candidate_bootstrap_home}" \
  "${candidate_bootstrap_log}" \
  > "${candidate_bootstrap_output}"
assert_equal \
  'omd 1.2.4' \
  "$("${candidate_bootstrap_home}/.local/bin/omd" --version)" \
  "candidate bootstrap updated version"
assert_contains \
  'Successfully updated omd to 1.2.4' \
  "${candidate_bootstrap_output}"

shell_repair_home="${tmp_dir}/shell-repair-home"
shell_repair_log="${tmp_dir}/shell-repair.log"
shell_repair_output="${tmp_dir}/shell-repair.out"
shell_repair_sudo_log="${tmp_dir}/shell-repair-sudo.log"
shell_repair_shells="${tmp_dir}/shell-repair-shells"
install_fixture github "${shell_repair_home}"
mkdir -p "${shell_repair_home}/.local/state/oh-my-devpod/managed"
cat > "${shell_repair_home}/.local/state/oh-my-devpod/managed/zsh-config" <<'EOF'
managed_by=oh-my-devpod
component=zsh-config
kind=configuration
artifact=/tmp/test-zshrc
EOF
: > "${shell_repair_sudo_log}"
: > "${shell_repair_shells}"
OMD_TEST_ID_UID=1002 \
  OMD_TEST_ID_USER=bywei \
  OMD_TEST_SUDO_LOG="${shell_repair_sudo_log}" \
  SUDO_USER=zhangdw \
  OHMYDEVPOD_CURRENT_SHELL=/bin/bash \
  OHMYDEVPOD_SHELLS_FILE="${shell_repair_shells}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  run_update "${shell_repair_home}" "${shell_repair_log}" >"${shell_repair_output}" 2>&1
assert_contains "tee -a ${shell_repair_shells}" "${shell_repair_sudo_log}"
assert_contains "chsh -s ${fake_bin}/zsh bywei" "${shell_repair_sudo_log}"
assert_absent "chsh -s ${fake_bin}/zsh zhangdw" "${shell_repair_sudo_log}"
assert_contains 'Successfully updated omd to 1.2.4' "${shell_repair_output}"

saved_github_home="${tmp_dir}/saved-github-home"
saved_github_log="${tmp_dir}/saved-github.log"
install_fixture github "${saved_github_home}"
run_update "${saved_github_home}" "${saved_github_log}" >/dev/null
assert_contains 'api.github.com' "${saved_github_log}"
assert_absent 'gitee.com' "${saved_github_log}"
assert_source_profile "${saved_github_home}" github upstream

gitee_home="${tmp_dir}/gitee-home"
gitee_log="${tmp_dir}/gitee.log"
install_fixture gitee "${gitee_home}"
printf 'source=gitee\n' > "${gitee_home}/.config/oh-my-devpod/source"
run_update "${gitee_home}" "${gitee_log}" >/dev/null
assert_contains 'gitee.com/api/' "${gitee_log}"
assert_absent 'api.github.com' "${gitee_log}"
assert_equal \
  'source=gitee' \
  "$(cat "${gitee_home}/.config/oh-my-devpod/source")" \
  "saved Gitee source should remain unchanged"
assert_equal \
  cn \
  "$(cat "${gitee_home}/.config/oh-my-devpod/mirror-profile")" \
  "saved Gitee mirror profile"

legacy_profile_home="${tmp_dir}/legacy-profile-home"
legacy_profile_log="${tmp_dir}/legacy-profile.log"
install_fixture gitee "${legacy_profile_home}"
cat > "${legacy_profile_home}/.config/oh-my-devpod/env" <<'EOF'
# Generated by oh-my-devpod. Use omd --update --github or --gitee to change this profile.
export OHMYDEVPOD_MIRROR_PROFILE=cn
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
export UV_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod/uv.toml"
EOF
run_update "${legacy_profile_home}" "${legacy_profile_log}" >/dev/null
assert_contains 'PIP_INDEX_URL' "${legacy_profile_home}/.config/oh-my-devpod/env"
assert_contains 'CONDA_CHANNELS="conda-forge"' "${legacy_profile_home}/.config/oh-my-devpod/env"
assert_contains 'MAMBA_CHANNEL_ALIAS' "${legacy_profile_home}/.config/oh-my-devpod/env"
assert_contains 'MAMBA_DEFAULT_CHANNELS' "${legacy_profile_home}/.config/oh-my-devpod/env"
assert_absent 'MAMBA_ROOT_PREFIX' "${legacy_profile_home}/.config/oh-my-devpod/env"

explicit_github_home="${tmp_dir}/explicit-github-home"
explicit_github_log="${tmp_dir}/explicit-github.log"
install_fixture gitee "${explicit_github_home}"
run_update "${explicit_github_home}" "${explicit_github_log}" --github >/dev/null
assert_contains 'api.github.com' "${explicit_github_log}"
assert_absent 'gitee.com' "${explicit_github_log}"
assert_source_profile "${explicit_github_home}" github upstream

explicit_gitee_home="${tmp_dir}/explicit-gitee-home"
explicit_gitee_log="${tmp_dir}/explicit-gitee.log"
install_fixture github "${explicit_gitee_home}"
run_update "${explicit_gitee_home}" "${explicit_gitee_log}" --gitee >/dev/null
assert_contains 'gitee.com/api/' "${explicit_gitee_log}"
assert_absent 'api.github.com' "${explicit_gitee_log}"
assert_source_profile "${explicit_gitee_home}" gitee cn

invalid_home="${tmp_dir}/invalid-home"
invalid_log="${tmp_dir}/invalid.log"
invalid_output="${tmp_dir}/invalid.out"
install_fixture github "${invalid_home}"
printf 'invalid-source\n' > "${invalid_home}/.config/oh-my-devpod/source"
run_update "${invalid_home}" "${invalid_log}" >"${invalid_output}" 2>&1
assert_contains "Invalid saved source 'invalid-source'; falling back to GitHub" "${invalid_output}"
assert_contains 'api.github.com' "${invalid_log}"
assert_equal \
  invalid-source \
  "$(cat "${invalid_home}/.config/oh-my-devpod/source")" \
  "implicit update should preserve an invalid saved source"
assert_equal \
  upstream \
  "$(cat "${invalid_home}/.config/oh-my-devpod/mirror-profile")" \
  "invalid source fallback profile"

switch_home="${tmp_dir}/switch-home"
switch_log="${tmp_dir}/switch.log"
component_log="${tmp_dir}/component.log"
install_fixture gitee "${switch_home}"
printf 'preserve me\n' > "${switch_home}/.config/oh-my-devpod/custom.conf"
mkdir -p "${switch_home}/.cache/oh-my-devpod" "${switch_home}/.local/state/oh-my-devpod"
printf 'cache\n' > "${switch_home}/.cache/oh-my-devpod/preserved-cache"
printf 'login\n' > "${switch_home}/.local/state/oh-my-devpod/preserved-login"
brew_repo="${tmp_dir}/managed-brew"
git init -q "${brew_repo}"
mkdir -p "${brew_repo}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${brew_repo}/bin/brew"
chmod +x "${brew_repo}/bin/brew"
git -C "${brew_repo}" remote add origin https://mirrors.ustc.edu.cn/brew.git
managed_dir="${switch_home}/.local/state/oh-my-devpod/managed"
mkdir -p "${managed_dir}"
cat > "${managed_dir}/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${brew_repo}
EOF

PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_VERSION="v1.2.3" \
  OHMYDEVPOD_TEST_CURL_LOG="${switch_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.3" \
  "${switch_home}/.local/bin/omd" --update --github >/dev/null
assert_source_profile "${switch_home}" github upstream
[[ ! -e "${component_log}" ]] ||
  fail "self-update must not execute component actions"
assert_absent 'mirrors.ustc.edu.cn' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'mirrors.tuna.tsinghua.edu.cn' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export HOMEBREW_BREW_GIT_REMOTE=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export HOMEBREW_BOTTLE_DOMAIN=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export HOMEBREW_API_DOMAIN=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export UV_CONFIG_FILE=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export PIP_INDEX_URL=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export CONDA_CHANNELS=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export MAMBA_CHANNEL_ALIAS=' "${switch_home}/.config/oh-my-devpod/env"
assert_absent 'export MAMBA_DEFAULT_CHANNELS=' "${switch_home}/.config/oh-my-devpod/env"
assert_contains 'unset HOMEBREW_BREW_GIT_REMOTE' "${switch_home}/.config/oh-my-devpod/env"
[[ ! -e "${switch_home}/.config/oh-my-devpod/uv.toml" ]] ||
  fail "GitHub switch should remove the managed uv mirror"
assert_equal \
  'https://github.com/Homebrew/brew.git' \
  "$(git -C "${brew_repo}" remote get-url origin)" \
  "managed Homebrew remote after GitHub switch"
assert_contains 'preserve me' "${switch_home}/.config/oh-my-devpod/custom.conf"
assert_contains 'cache' "${switch_home}/.cache/oh-my-devpod/preserved-cache"
assert_contains 'login' "${switch_home}/.local/state/oh-my-devpod/preserved-login"
github_config_hash="$(
  cat \
    "${switch_home}/.config/oh-my-devpod/source" \
    "${switch_home}/.config/oh-my-devpod/mirror-profile" \
    "${switch_home}/.config/oh-my-devpod/env" |
    sha256sum |
    awk '{print $1}'
)"
PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_VERSION="v1.2.3" \
  OHMYDEVPOD_TEST_CURL_LOG="${switch_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.3" \
  "${switch_home}/.local/bin/omd" --update --github >/dev/null
assert_equal \
  "${github_config_hash}" \
  "$(
    cat \
      "${switch_home}/.config/oh-my-devpod/source" \
      "${switch_home}/.config/oh-my-devpod/mirror-profile" \
      "${switch_home}/.config/oh-my-devpod/env" |
      sha256sum |
      awk '{print $1}'
  )" \
  "repeated GitHub switch should be idempotent"

printf 'cn\n' > "${switch_home}/.config/oh-my-devpod/mirror-profile"
PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_TEST_COMPONENT_LOG="${component_log}" \
  OHMYDEVPOD_MIRROR_PROFILE="cn" \
  HOMEBREW_BREW_GIT_REMOTE="https://stale.invalid/brew.git" \
  HOMEBREW_BOTTLE_DOMAIN="https://stale.invalid/bottles" \
  HOMEBREW_API_DOMAIN="https://stale.invalid/api" \
  UV_CONFIG_FILE="${tmp_dir}/stale-uv.toml" \
  PIP_INDEX_URL="https://stale.invalid/simple" \
  CONDA_CHANNELS="stale-channel" \
  MAMBA_CHANNEL_ALIAS="https://stale.invalid/anaconda/cloud" \
  MAMBA_DEFAULT_CHANNELS="https://stale.invalid/anaconda/pkgs/main" \
  "${switch_home}/.local/bin/omd" --execute install probe >/dev/null
assert_contains 'profile=upstream' "${component_log}"
assert_contains 'brew_git=' "${component_log}"
assert_contains 'brew_core=' "${component_log}"
assert_contains 'pip_index=' "${component_log}"
assert_contains 'conda_channels=' "${component_log}"
assert_contains 'mamba_channel_alias=' "${component_log}"
assert_contains 'mamba_default_channels=' "${component_log}"
assert_absent 'stale.invalid' "${component_log}"
component_hash="$(sha256sum "${component_log}" | awk '{print $1}')"

PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_VERSION="v1.2.3" \
  OHMYDEVPOD_TEST_CURL_LOG="${switch_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.3" \
  "${switch_home}/.local/bin/omd" --update --gitee >/dev/null
assert_equal \
  "${component_hash}" \
  "$(sha256sum "${component_log}" | awk '{print $1}')" \
  "source switching must not run component actions"
assert_source_profile "${switch_home}" gitee cn
assert_contains 'mirrors.ustc.edu.cn' "${switch_home}/.config/oh-my-devpod/env"
assert_contains 'mirrors.tuna.tsinghua.edu.cn' "${switch_home}/.config/oh-my-devpod/uv.toml"
assert_contains 'PIP_INDEX_URL' "${switch_home}/.config/oh-my-devpod/env"
assert_contains 'CONDA_CHANNELS="conda-forge"' "${switch_home}/.config/oh-my-devpod/env"
assert_contains 'MAMBA_CHANNEL_ALIAS' "${switch_home}/.config/oh-my-devpod/env"
assert_contains 'MAMBA_DEFAULT_CHANNELS' "${switch_home}/.config/oh-my-devpod/env"
assert_equal \
  'https://mirrors.ustc.edu.cn/brew.git' \
  "$(git -C "${brew_repo}" remote get-url origin)" \
  "managed Homebrew remote after Gitee switch"

PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_TEST_COMPONENT_LOG="${component_log}" \
  HOMEBREW_BREW_GIT_REMOTE="https://stale.invalid/brew.git" \
  HOMEBREW_BOTTLE_DOMAIN="https://stale.invalid/bottles" \
  HOMEBREW_API_DOMAIN="https://stale.invalid/api" \
  UV_CONFIG_FILE="${tmp_dir}/stale-uv.toml" \
  PIP_INDEX_URL="https://stale.invalid/simple" \
  CONDA_CHANNELS="stale-channel" \
  MAMBA_CHANNEL_ALIAS="https://stale.invalid/anaconda/cloud" \
  MAMBA_DEFAULT_CHANNELS="https://stale.invalid/anaconda/pkgs/main" \
  "${switch_home}/.local/bin/omd" --execute install probe >/dev/null
assert_contains 'profile=cn' "${component_log}"
assert_contains 'mirrors.ustc.edu.cn' "${component_log}"
assert_contains 'brew_core=https://mirrors.ustc.edu.cn/homebrew-core.git' "${component_log}"
assert_contains 'uv_config=' "${component_log}"
assert_contains 'pip_index=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple' "${component_log}"
assert_contains 'conda_channels=conda-forge' "${component_log}"
assert_contains \
  'mamba_channel_alias=https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud' \
  "${component_log}"
assert_contains \
  'mamba_default_channels=https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main,https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r' \
  "${component_log}"

: > "${switch_log}"
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${switch_home}" \
  OHMYDEVPOD_TEST_CURL_LOG="${switch_log}" \
  "${switch_home}/.local/bin/omd" --update --github --gitee >/dev/null 2>&1; then
  fail "--github and --gitee must be mutually exclusive"
fi
[[ ! -s "${switch_log}" ]] || fail "invalid source flags must fail before network access"
assert_source_profile "${switch_home}" gitee cn

legacy_home="${tmp_dir}/legacy-home"
legacy_log="${tmp_dir}/legacy.log"
legacy_brew="${tmp_dir}/legacy-brew"
legacy_core="${legacy_brew}/Library/Taps/homebrew/homebrew-core"
brew_source="${tmp_dir}/brew-source"
brew_remote="${tmp_dir}/brew-remote.git"
install_fixture github "${legacy_home}"
git init -q "${brew_source}"
mkdir -p "${brew_source}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${brew_source}/bin/brew"
chmod +x "${brew_source}/bin/brew"
git -C "${brew_source}" add bin/brew
git -C "${brew_source}" \
  -c user.name=oh-my-devpod \
  -c user.email=oh-my-devpod@example.invalid \
  commit -qm initial
git clone -q --bare "${brew_source}" "${brew_remote}"
mkdir -p "${legacy_brew}/bin" "${legacy_brew}/Cellar/preserved/1.0"
printf '#!/usr/bin/env bash\nexit 0\n' > "${legacy_brew}/bin/brew"
chmod +x "${legacy_brew}/bin/brew"
git init -q "${legacy_core}"
git -C "${legacy_core}" remote add origin https://github.com/Homebrew/homebrew-core.git
mkdir -p "${legacy_home}/.local/state/oh-my-devpod/managed"
cat > "${legacy_home}/.local/state/oh-my-devpod/managed/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${legacy_brew}
EOF
PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${legacy_home}" \
  OHMYDEVPOD_VERSION="v1.2.3" \
  OHMYDEVPOD_GITEE_BREW_REMOTE="${brew_remote}" \
  OHMYDEVPOD_TEST_CURL_LOG="${legacy_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.3" \
  "${legacy_home}/.local/bin/omd" --update --gitee >/dev/null
[[ -d "${legacy_brew}/.git" ]] ||
  fail "legacy managed Homebrew should gain Git metadata during a source switch"
assert_equal \
  "${brew_remote}" \
  "$(git -C "${legacy_brew}" remote get-url origin)" \
  "legacy managed Homebrew remote"
assert_equal \
  'https://mirrors.ustc.edu.cn/homebrew-core.git' \
  "$(git -C "${legacy_core}" remote get-url origin)" \
  "legacy managed Homebrew core remote"
grep -Fq 'exit 0' "${legacy_brew}/bin/brew" ||
  fail "legacy Homebrew source switching must not update component files"
[[ -d "${legacy_brew}/Cellar/preserved/1.0" ]] ||
  fail "legacy Homebrew migration must preserve installed formulae"

ownership_home="${tmp_dir}/ownership-home"
ownership_log="${tmp_dir}/ownership.log"
install_fixture github "${ownership_home}"
printf 'export USER_SETTING=preserve\n' > "${ownership_home}/.config/oh-my-devpod/env"
printf 'user uv config\n' > "${ownership_home}/.config/oh-my-devpod/uv.toml"
run_update "${ownership_home}" "${ownership_log}" >/dev/null
assert_equal 'omd 1.2.4' "$("${ownership_home}/.local/bin/omd" --version)" \
  "ordinary self-update with user-managed source files"
assert_contains 'export USER_SETTING=preserve' "${ownership_home}/.config/oh-my-devpod/env"
assert_contains 'user uv config' "${ownership_home}/.config/oh-my-devpod/uv.toml"
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${ownership_home}" \
  OHMYDEVPOD_VERSION="v1.2.4" \
  OHMYDEVPOD_TEST_CURL_LOG="${ownership_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.4" \
  "${ownership_home}/.local/bin/omd" --update --gitee >/dev/null 2>&1; then
  fail "source switching should refuse to overwrite user-managed configuration"
fi
assert_contains 'export USER_SETTING=preserve' "${ownership_home}/.config/oh-my-devpod/env"
assert_contains 'user uv config' "${ownership_home}/.config/oh-my-devpod/uv.toml"
assert_source_profile "${ownership_home}" github upstream

failure_home="${tmp_dir}/failure-home"
failure_log="${tmp_dir}/failure.log"
install_fixture gitee "${failure_home}"
before_link="$(readlink "${failure_home}/.local/bin/omd")"
before_source="$(cat "${failure_home}/.config/oh-my-devpod/source")"
before_profile="$(cat "${failure_home}/.config/oh-my-devpod/mirror-profile")"

if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${failure_home}" \
  OHMYDEVPOD_TEST_ARCHIVE="${archive_124}" \
  OHMYDEVPOD_TEST_CHECKSUM="${checksum_124}" \
  OHMYDEVPOD_TEST_CURL_LOG="${failure_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.4" \
  OHMYDEVPOD_TEST_DOWNLOAD_FAIL=1 \
  "${failure_home}/.local/bin/omd" --update --github >/dev/null 2>&1; then
  fail "download failure should fail self-update"
fi
assert_equal "${before_link}" "$(readlink "${failure_home}/.local/bin/omd")" "active version after download failure"
assert_source_profile "${failure_home}" "${before_source}" "${before_profile}"

bad_checksum="${tmp_dir}/bad.sha256"
printf '%064d  %s\n' 0 "$(basename "${archive_124}")" > "${bad_checksum}"
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${failure_home}" \
  OHMYDEVPOD_TEST_ARCHIVE="${archive_124}" \
  OHMYDEVPOD_TEST_CHECKSUM="${bad_checksum}" \
  OHMYDEVPOD_TEST_CURL_LOG="${failure_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.4" \
  "${failure_home}/.local/bin/omd" --update --github >/dev/null 2>&1; then
  fail "checksum failure should fail self-update"
fi
assert_equal "${before_link}" "$(readlink "${failure_home}/.local/bin/omd")" "active version after checksum failure"
assert_source_profile "${failure_home}" "${before_source}" "${before_profile}"

invalid_archive="${tmp_dir}/invalid-release.tar.gz"
invalid_checksum="${invalid_archive}.sha256"
mkdir -p "${tmp_dir}/invalid-payload/oh-my-devpod"
printf 'invalid bundle\n' > "${tmp_dir}/invalid-payload/oh-my-devpod/VERSION"
tar -czf "${invalid_archive}" -C "${tmp_dir}/invalid-payload" oh-my-devpod
(
  cd "${tmp_dir}"
  sha256sum "$(basename "${invalid_archive}")" > "$(basename "${invalid_checksum}")"
)
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${failure_home}" \
  OHMYDEVPOD_OMD_ARCHIVE="${invalid_archive}" \
  OHMYDEVPOD_OMD_CHECKSUM="${invalid_checksum}" \
  OHMYDEVPOD_TEST_CURL_LOG="${failure_log}" \
  "${failure_home}/.local/bin/omd" --update --github >/dev/null 2>&1; then
  fail "invalid release archive should fail self-update"
fi
assert_equal "${before_link}" "$(readlink "${failure_home}/.local/bin/omd")" "active version after install validation failure"
assert_source_profile "${failure_home}" "${before_source}" "${before_profile}"

activation_failure_home="${tmp_dir}/activation-failure-home"
activation_failure_log="${tmp_dir}/activation-failure.log"
install_fixture gitee "${activation_failure_home}"
activation_failure_link="$(readlink "${activation_failure_home}/.local/bin/omd")"
activation_brew_repo="${tmp_dir}/activation-managed-brew"
git init -q "${activation_brew_repo}"
mkdir -p "${activation_brew_repo}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${activation_brew_repo}/bin/brew"
chmod +x "${activation_brew_repo}/bin/brew"
git -C "${activation_brew_repo}" remote add origin https://mirrors.ustc.edu.cn/brew.git
mkdir -p "${activation_failure_home}/.local/state/oh-my-devpod/managed"
cat > "${activation_failure_home}/.local/state/oh-my-devpod/managed/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${activation_brew_repo}
EOF
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${activation_failure_home}" \
  OHMYDEVPOD_TEST_ARCHIVE="${archive_124}" \
  OHMYDEVPOD_TEST_CHECKSUM="${checksum_124}" \
  OHMYDEVPOD_TEST_CURL_LOG="${activation_failure_log}" \
  OHMYDEVPOD_TEST_LATEST_VERSION="1.2.4" \
  OHMYDEVPOD_TEST_FAIL_ACTIVATION=1 \
  "${activation_failure_home}/.local/bin/omd" --update --github >/dev/null 2>&1; then
  fail "activation failure should fail self-update"
fi
assert_equal \
  "${activation_failure_link}" \
  "$(readlink "${activation_failure_home}/.local/bin/omd")" \
  "active version after activation failure"
assert_source_profile "${activation_failure_home}" gitee cn
assert_equal \
  'https://mirrors.ustc.edu.cn/brew.git' \
  "$(git -C "${activation_brew_repo}" remote get-url origin)" \
  "managed Homebrew remote after activation rollback"

source_only_home="${tmp_dir}/source-only-home"
source_only_log="${tmp_dir}/source-only.log"
source_only_output="${tmp_dir}/source-only.out"
install_fixture github "${source_only_home}"
source_only_brew="${tmp_dir}/source-only-brew"
source_only_core="${source_only_brew}/Library/Taps/homebrew/homebrew-core"
mkdir -p \
  "${source_only_brew}/bin" \
  "${source_only_brew}/Cellar/uv/1.0" \
  "${source_only_brew}/Cellar/micromamba/1.0" \
  "${source_only_core}"
printf '#!/usr/bin/env bash\nexit 0\n' > "${source_only_brew}/bin/brew"
chmod +x "${source_only_brew}/bin/brew"
git init -q "${source_only_brew}"
git -C "${source_only_brew}" remote add origin https://github.com/Homebrew/brew.git
git init -q "${source_only_core}"
git -C "${source_only_core}" remote add origin https://github.com/Homebrew/homebrew-core.git
source_only_managed="${source_only_home}/.local/state/oh-my-devpod/managed"
mkdir -p "${source_only_managed}"
cat > "${source_only_managed}/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${source_only_brew}
EOF
for component in uv micromamba; do
  cat > "${source_only_managed}/${component}" <<EOF
managed_by=oh-my-devpod
component=${component}
kind=brew-formula
artifact=${component}
EOF
done
: > "${source_only_log}"
PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${source_only_home}" \
  OHMYDEVPOD_BREW_BIN="${source_only_brew}/bin/brew" \
  OHMYDEVPOD_TEST_CURL_LOG="${source_only_log}" \
  "${source_only_home}/.local/bin/omd" --source gitee > "${source_only_output}"
assert_source_profile "${source_only_home}" gitee cn
[[ ! -s "${source_only_log}" ]] ||
  fail "source-only switching must not query or download a release"
assert_contains 'Source configuration updated successfully.' "${source_only_output}"
assert_contains \
  'HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles' \
  "${source_only_brew}/etc/homebrew/brew.env"
assert_contains \
  'https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple' \
  "${source_only_home}/.config/uv/uv.toml"
assert_contains \
  'index-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple' \
  "${source_only_home}/.config/pip/pip.conf"
assert_contains \
  'channel_alias: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud' \
  "${source_only_home}/.mambarc"
assert_equal \
  'https://mirrors.ustc.edu.cn/brew.git' \
  "$(git -C "${source_only_brew}" remote get-url origin)" \
  "managed Homebrew remote after source-only switch"
assert_equal \
  'https://mirrors.ustc.edu.cn/homebrew-core.git' \
  "$(git -C "${source_only_core}" remote get-url origin)" \
  "managed Homebrew core remote after source-only switch"
[[ -d "${source_only_brew}/Cellar/uv/1.0" ]] ||
  fail "source switching should preserve the installed uv formula"
[[ -d "${source_only_brew}/Cellar/micromamba/1.0" ]] ||
  fail "source switching should preserve the installed micromamba formula"

PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${source_only_home}" \
  OHMYDEVPOD_BREW_BIN="${source_only_brew}/bin/brew" \
  OHMYDEVPOD_TEST_CURL_LOG="${source_only_log}" \
  "${source_only_home}/.local/bin/omd" --source github >/dev/null
assert_source_profile "${source_only_home}" github upstream
[[ ! -s "${source_only_log}" ]] ||
  fail "repeated source-only switching must remain network-free"
for path in \
  "${source_only_brew}/etc/homebrew/brew.env" \
  "${source_only_home}/.config/uv/uv.toml" \
  "${source_only_home}/.config/pip/pip.conf" \
  "${source_only_home}/.mambarc"; do
  [[ ! -e "${path}" ]] ||
    fail "upstream source switch should remove managed native config: ${path}"
done
assert_equal \
  'https://github.com/Homebrew/brew.git' \
  "$(git -C "${source_only_brew}" remote get-url origin)" \
  "managed Homebrew remote after upstream source-only switch"
assert_equal \
  'https://github.com/Homebrew/homebrew-core.git' \
  "$(git -C "${source_only_core}" remote get-url origin)" \
  "managed Homebrew core remote after upstream source-only switch"

native_failure_home="${tmp_dir}/native-failure-home"
native_failure_log="${tmp_dir}/native-failure.log"
native_failure_brew="${tmp_dir}/native-failure-brew"
install_fixture github "${native_failure_home}"
mkdir -p "${native_failure_brew}/bin" "${native_failure_brew}/Cellar/uv/1.0"
printf '#!/usr/bin/env bash\nexit 0\n' > "${native_failure_brew}/bin/brew"
chmod +x "${native_failure_brew}/bin/brew"
git init -q "${native_failure_brew}"
git -C "${native_failure_brew}" remote add origin https://github.com/Homebrew/brew.git
native_failure_managed="${native_failure_home}/.local/state/oh-my-devpod/managed"
mkdir -p "${native_failure_managed}"
cat > "${native_failure_managed}/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${native_failure_brew}
EOF
cat > "${native_failure_managed}/uv" <<'EOF'
managed_by=oh-my-devpod
component=uv
kind=brew-formula
artifact=uv
EOF
printf 'user-owned blocker\n' > "${native_failure_home}/.config/uv"
: > "${native_failure_log}"
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${native_failure_home}" \
  OHMYDEVPOD_BREW_BIN="${native_failure_brew}/bin/brew" \
  OHMYDEVPOD_TEST_CURL_LOG="${native_failure_log}" \
  "${native_failure_home}/.local/bin/omd" --source gitee >/dev/null 2>&1; then
  fail "native source write failure should fail the source switch"
fi
assert_source_profile "${native_failure_home}" github upstream
assert_equal \
  'https://github.com/Homebrew/brew.git' \
  "$(git -C "${native_failure_brew}" remote get-url origin)" \
  "Homebrew remote after native source rollback"
[[ ! -e "${native_failure_brew}/etc/homebrew/brew.env" ]] ||
  fail "native source rollback should remove the newly created brew.env"
assert_contains 'user-owned blocker' "${native_failure_home}/.config/uv"
[[ ! -s "${native_failure_log}" ]] ||
  fail "failed native source migration must remain release-network-free"

npm_source_home="${tmp_dir}/npm-source-home"
npm_source_log="${tmp_dir}/npm-source.log"
install_fixture github "${npm_source_home}"
original_bootstrap_source="$(
  cat "${npm_source_home}/.config/oh-my-devpod/source"
)"
: > "${npm_source_log}"
PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${npm_source_home}" \
  OHMYDEVPOD_INSTALL_CHANNEL=npm \
  OHMYDEVPOD_NPM_SOURCE=github \
  OHMYDEVPOD_TEST_CURL_LOG="${npm_source_log}" \
  "${npm_source_home}/.local/bin/omd" --source gitee >/dev/null
assert_equal \
  gitee \
  "$(cat "${npm_source_home}/.config/oh-my-devpod/npm-source")" \
  "npm source selection"
assert_equal \
  "${original_bootstrap_source}" \
  "$(cat "${npm_source_home}/.config/oh-my-devpod/source")" \
  "npm source switch should not rewrite bootstrap ownership"
assert_equal \
  cn \
  "$(cat "${npm_source_home}/.config/oh-my-devpod/mirror-profile")" \
  "npm mirror profile"
[[ ! -s "${npm_source_log}" ]] ||
  fail "npm source switching must not invoke the release updater"

if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${npm_source_home}" \
  OHMYDEVPOD_INSTALL_CHANNEL=npm \
  OHMYDEVPOD_NPM_SOURCE=gitee \
  "${npm_source_home}/.local/bin/omd" --source mirror >/dev/null 2>&1; then
  fail "invalid source names should be rejected"
fi
assert_equal \
  gitee \
  "$(cat "${npm_source_home}/.config/oh-my-devpod/npm-source")" \
  "invalid source request should preserve npm selection"

help_output="$("${omd_binary}" --help)"
grep -Fq 'omd --update [--github|--gitee]' <<<"${help_output}" ||
  fail "help should document self-update and source switching"
grep -Fq 'omd --source <github|gitee>' <<<"${help_output}" ||
  fail "help should document source-only switching"

echo "self-update tests passed"
