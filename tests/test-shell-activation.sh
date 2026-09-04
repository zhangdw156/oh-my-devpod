#!/usr/bin/env bash
set -euo pipefail

unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_root}/modules/lib/common.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fake_bin="${tmp_dir}/bin"
brew_log="${tmp_dir}/brew.log"
sudo_log="${tmp_dir}/sudo.log"
mamba_log="${tmp_dir}/mamba.log"
shells_file="${tmp_dir}/shells"
state_dir="${tmp_dir}/state"
zsh_prefix="${tmp_dir}/zsh-prefix"
zsh_path="${zsh_prefix}/bin/zsh"
mkdir -p \
  "${fake_bin}" \
  "${state_dir}/managed" \
  "$(dirname "${zsh_path}")" \
  "${tmp_dir}/Cellar/uv/1.0"
: > "${shells_file}"

cat > "${fake_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s|%s|%s|%s|%s|%s\n' \
  "${NONINTERACTIVE:-}" \
  "${HOMEBREW_NO_ASK:-}" \
  "${HOMEBREW_ASK:-unset}" \
  "${HOMEBREW_NO_AUTO_UPDATE:-}" \
  "${HOMEBREW_NO_ENV_HINTS:-}" \
  "${HOMEBREW_NO_INSTALL_CLEANUP:-}" \
  "$*" >> "${OMD_TEST_BREW_LOG}"
if [[ "${1:-}" == "--prefix" && "${2:-}" == "zsh" ]]; then
  printf '%s\n' "${OMD_TEST_ZSH_PREFIX}"
elif [[ "${1:-}" == "--prefix" && "$#" -eq 1 ]]; then
  cd "$(dirname "$0")/.." && pwd -P
fi
EOF

cat > "${fake_bin}/id" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -u) printf '%s\n' "${OMD_TEST_ID_UID:-1000}" ;;
  -un) printf '%s\n' "${OMD_TEST_ID_USER:-test-user}" ;;
  *) exit 2 ;;
esac
EOF

cat > "${fake_bin}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${OMD_TEST_SUDO_LOG}"
case "${1:-}" in
  tee)
    shift
    tee "$@"
    ;;
  chsh)
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
EOF

cat > "${fake_bin}/mamba" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mamba:%s\n' "$*" >> "${OMD_TEST_MAMBA_LOG}"
[[ "${OMD_TEST_MAMBA_FAIL:-0}" != "1" ]] || exit 1
if [[ "$*" == "shell hook --shell zsh" ]]; then
  printf 'export OMD_TEST_MAMBA_HOOK=loaded\n'
  exit 0
fi
exit 2
EOF

cat > "${fake_bin}/micromamba" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'micromamba:%s\n' "$*" >> "${OMD_TEST_MAMBA_LOG}"
if [[ "$*" == "shell hook --shell zsh" ]]; then
  printf 'export OMD_TEST_MAMBA_HOOK=fallback\n'
  exit 0
fi
exit 2
EOF

cat > "${zsh_path}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x \
  "${fake_bin}/brew" \
  "${fake_bin}/id" \
  "${fake_bin}/sudo" \
  "${fake_bin}/mamba" \
  "${fake_bin}/micromamba" \
  "${zsh_path}"

OMD_TEST_BREW_LOG="${brew_log}" \
  HOMEBREW_ASK=1 \
  omd_module_brew_exec "${fake_bin}/brew" install micromamba
grep -Fqx '1|1|unset|1|1|1|install micromamba' "${brew_log}" ||
  fail "Homebrew commands must disable ask mode and auto-update prompts"

mkdir -p "${tmp_dir}/Cellar/yazi/26.8.15"
brew_log_lines="$(wc -l < "${brew_log}")"
HOMEBREW_PREFIX="" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  omd_module_brew_formula_installed yazi ||
  fail "filesystem inventory should detect an installed Homebrew formula"
HOMEBREW_PREFIX="" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  omd_module_brew_formula_installed missing-formula &&
  fail "filesystem inventory should reject a missing Homebrew formula"
[[ "$(wc -l < "${brew_log}")" -eq "${brew_log_lines}" ]] ||
  fail "formula status checks must not launch Homebrew"

resolved="$(
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
    OMD_TEST_BREW_LOG="${brew_log}" \
    OMD_TEST_ZSH_PREFIX="${zsh_prefix}" \
    omd_module_zsh_path
)"
[[ "${resolved}" == "${zsh_path}" ]] ||
  fail "expected Homebrew Zsh path ${zsh_path}, got ${resolved}"

effective_target="$(
  PATH="${fake_bin}:${PATH}" \
    SUDO_USER="zhangdw" \
    OMD_TEST_ID_UID=1002 \
    OMD_TEST_ID_USER="bywei" \
    omd_module_target_user
)"
[[ "${effective_target}" == "bywei" ]] ||
  fail "non-root shell changes should target the effective user, got ${effective_target}"

sudo_target="$(
  PATH="${fake_bin}:${PATH}" \
    SUDO_USER="bywei" \
    OMD_TEST_ID_UID=0 \
    OMD_TEST_ID_USER="root" \
    omd_module_target_user
)"
[[ "${sudo_target}" == "bywei" ]] ||
  fail "root shell changes should target the original sudo user, got ${sudo_target}"

PATH="${fake_bin}:${PATH}" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_CURRENT_SHELL="/bin/bash" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  omd_module_set_login_shell "${zsh_path}" >/dev/null

grep -Fqx "${zsh_path}" "${shells_file}" ||
  fail "Zsh path was not added to the shells file"
grep -Fqx "tee -a ${shells_file}" "${sudo_log}" ||
  fail "expected privileged shells-file update"
grep -Fqx "chsh -s ${zsh_path} test-user" "${sudo_log}" ||
  fail "expected login shell change for the invoking user"

: > "${sudo_log}"
PATH="${fake_bin}:${PATH}" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_CURRENT_SHELL="${zsh_path}" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  omd_module_set_login_shell "${zsh_path}" >/dev/null

[[ ! -s "${sudo_log}" ]] ||
  fail "already active login shell should not trigger privileged changes"

custom_config_dir="${tmp_dir}/custom-config"
managed_zsh_dir="${tmp_dir}/managed-zsh"
managed_zshrc="${tmp_dir}/managed.zshrc"
managed_p10k="${tmp_dir}/managed.p10k.zsh"
test_mamba_root="${tmp_dir}/mamba-root"
mkdir -p "${custom_config_dir}"
printf 'export MAMBA_ROOT_PREFIX=%q\n' "${test_mamba_root}" > "${custom_config_dir}/env"
: > "${sudo_log}"
: > "${mamba_log}"
PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  OHMYDEVPOD_ASSET_ROOT="${repo_root}/vendor/releases" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  OHMYDEVPOD_CONFIG_DIR="${custom_config_dir}" \
  OHMYDEVPOD_CURRENT_SHELL="${zsh_path}" \
  OHMYDEVPOD_P10K_CONFIG="${managed_p10k}" \
  OHMYDEVPOD_PREFIX="${tmp_dir}/prefix" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_STATE_DIR="${state_dir}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_ZSH_DIR="${managed_zsh_dir}" \
  OHMYDEVPOD_ZSHRC="${managed_zshrc}" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_MAMBA_LOG="${mamba_log}" \
  OMD_TEST_ZSH_PREFIX="${zsh_prefix}" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  bash "${repo_root}/modules/tools/zsh-config.sh" install >/dev/null

grep -Fqx "export OHMYDEVPOD_CONFIG_DIR=${custom_config_dir}" "${managed_zshrc}" ||
  fail "managed Zsh should persist the configured OMD config directory"
grep -Fq 'source "${OHMYDEVPOD_CONFIG_DIR}/env"' "${managed_zshrc}" ||
  fail "managed Zsh should source mirrors from the configured OMD directory"
grep -Fq 'mamba shell hook --shell zsh' "${managed_zshrc}" ||
  fail "managed Zsh should initialize the mamba shell hook"
grep -Fq 'micromamba shell hook --shell zsh' "${managed_zshrc}" ||
  fail "managed Zsh should fall back to the micromamba shell hook"
grep -Fqx 'plugins=(git extract z)' "${managed_zshrc}" ||
  fail "managed Zsh should enable the built-in z directory-jump plugin"
[[ -f "${managed_zsh_dir}/ohmyzsh/plugins/z/z.plugin.zsh" ]] ||
  fail "managed Zsh assets should include the built-in z plugin"

ZSHZ_DATA="${tmp_dir}/z-data" \
  PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_MAMBA_LOG="${mamba_log}" \
  zsh -dfc '
    source "$1"
    (( ${plugins[(Ie)z]} ))
    (( ${+functions[zshz]} ))
    [[ "${aliases[z]-}" == "zshz 2>&1" ]]
  ' _ "${managed_zshrc}" ||
  fail "managed Zsh should load the built-in z plugin"

managed_zsh_prelude="${tmp_dir}/managed-zsh-prelude.zsh"
awk '/^# Enable Powerlevel10k/{exit} {print}' "${managed_zshrc}" > "${managed_zsh_prelude}"
PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_MAMBA_LOG="${mamba_log}" \
  zsh -dfc '
    source "$1"
    [[ "${MAMBA_ROOT_PREFIX}" == "$2" ]]
    [[ "${OMD_TEST_MAMBA_HOOK}" == "loaded" ]]
  ' _ "${managed_zsh_prelude}" "${test_mamba_root}" ||
  fail "managed Zsh prelude should load the mamba root and shell hook"
grep -Fqx 'mamba:shell hook --shell zsh' "${mamba_log}" ||
  fail "managed Zsh should invoke the mamba Zsh hook"

: > "${mamba_log}"
PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_MAMBA_FAIL=1 \
  OMD_TEST_MAMBA_LOG="${mamba_log}" \
  zsh -dfc '
    source "$1"
    [[ "${OMD_TEST_MAMBA_HOOK}" == "fallback" ]]
  ' _ "${managed_zsh_prelude}" ||
  fail "managed Zsh should fall back when the mamba hook fails"
grep -Fqx 'mamba:shell hook --shell zsh' "${mamba_log}" ||
  fail "fallback test should attempt the mamba hook first"
grep -Fqx 'micromamba:shell hook --shell zsh' "${mamba_log}" ||
  fail "fallback test should invoke the micromamba hook"

if [[ -n "${OMD_TEST_REAL_MAMBA_BIN:-}" ]]; then
  [[ -x "${OMD_TEST_REAL_MAMBA_BIN}" ]] ||
    fail "real Micromamba binary is not executable: ${OMD_TEST_REAL_MAMBA_BIN}"
  rm -f "${fake_bin}/mamba" "${fake_bin}/micromamba"
  cp "${OMD_TEST_REAL_MAMBA_BIN}" "${fake_bin}/mamba"
  ln -s mamba "${fake_bin}/micromamba"
  MAMBA_ROOT_PREFIX="${test_mamba_root}" \
    "${fake_bin}/mamba" create -n real-hook-probe -y >/dev/null
  PATH="${fake_bin}:${PATH}" \
    HOME="${tmp_dir}/home" \
    OMD_TEST_BREW_LOG="${brew_log}" \
    zsh -dfc '
      source "$1"
      mamba activate real-hook-probe
      [[ "${CONDA_PREFIX}" == "${MAMBA_ROOT_PREFIX}/envs/real-hook-probe" ]]
      [[ "${CONDA_DEFAULT_ENV}" == "real-hook-probe" ]]
    ' _ "${managed_zsh_prelude}" ||
    fail "Micromamba should activate an environment under the existing root prefix"
fi

cat > "${state_dir}/managed/zsh-config" <<'EOF'
managed_by=oh-my-devpod
component=zsh-config
kind=configuration
artifact=/tmp/test-zshrc
EOF
cat > "${state_dir}/managed/uv" <<EOF
managed_by=oh-my-devpod
component=uv
kind=brew-formula
artifact=uv
brew_prefix=${tmp_dir}
EOF
: > "${shells_file}"
: > "${sudo_log}"
PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  XDG_CONFIG_HOME="${tmp_dir}/postflight-config" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_CURRENT_SHELL="/bin/bash" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OHMYDEVPOD_STATE_DIR="${state_dir}" \
  OHMYDEVPOD_MIRROR_PROFILE=cn \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_ZSH_PREFIX="${zsh_prefix}" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  bash "${repo_root}/modules/lib/postflight.sh" install >/dev/null

grep -Fqx "chsh -s ${zsh_path} test-user" "${sudo_log}" ||
  fail "install postflight should migrate an existing managed Zsh installation"
grep -Fq 'mirrors.tuna.tsinghua.edu.cn' \
  "${tmp_dir}/postflight-config/uv/uv.toml" ||
  fail "install postflight should configure an already managed uv installation"
printf '# user modification\n' >> "${tmp_dir}/postflight-config/uv/uv.toml"
PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  XDG_CONFIG_HOME="${tmp_dir}/postflight-config" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_CURRENT_SHELL="${zsh_path}" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OHMYDEVPOD_STATE_DIR="${state_dir}" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_ZSH_PREFIX="${zsh_prefix}" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  bash "${repo_root}/modules/lib/postflight.sh" repair-login-shell >/dev/null
grep -Fq '# user modification' "${tmp_dir}/postflight-config/uv/uv.toml" ||
  fail "login-shell repair should not touch native source configuration"
if PATH="${fake_bin}:${PATH}" \
  HOME="${tmp_dir}/home" \
  XDG_CONFIG_HOME="${tmp_dir}/postflight-config" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  OHMYDEVPOD_STATE_DIR="${state_dir}" \
  OHMYDEVPOD_MIRROR_PROFILE=cn \
  bash "${repo_root}/modules/lib/postflight.sh" update >/dev/null 2>&1; then
  fail "postflight should report native source configuration conflicts"
fi
grep -Fq '# user modification' "${tmp_dir}/postflight-config/uv/uv.toml" ||
  fail "postflight should preserve modified native source configuration"

echo "shell activation tests passed"
