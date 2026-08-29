#!/usr/bin/env bash
set -euo pipefail

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
shells_file="${tmp_dir}/shells"
state_dir="${tmp_dir}/state"
zsh_prefix="${tmp_dir}/zsh-prefix"
zsh_path="${zsh_prefix}/bin/zsh"
mkdir -p "${fake_bin}" "${state_dir}/managed" "$(dirname "${zsh_path}")"
: > "${shells_file}"

cat > "${fake_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s|%s|%s|%s\n' \
  "${NONINTERACTIVE:-}" \
  "${HOMEBREW_NO_AUTO_UPDATE:-}" \
  "${HOMEBREW_NO_ENV_HINTS:-}" \
  "${HOMEBREW_NO_INSTALL_CLEANUP:-}" \
  "$*" >> "${OMD_TEST_BREW_LOG}"
if [[ "${1:-}" == "--prefix" && "${2:-}" == "zsh" ]]; then
  printf '%s\n' "${OMD_TEST_ZSH_PREFIX}"
fi
EOF

cat > "${fake_bin}/id" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -u) printf '1000\n' ;;
  -un) printf 'test-user\n' ;;
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

cat > "${zsh_path}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin}/brew" "${fake_bin}/id" "${fake_bin}/sudo" "${zsh_path}"

OMD_TEST_BREW_LOG="${brew_log}" \
  omd_module_brew_exec "${fake_bin}/brew" install jq
grep -Fqx '1|1|1|1|install jq' "${brew_log}" ||
  fail "Homebrew commands must run non-interactively without auto-update prompts"

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

cat > "${state_dir}/managed/zsh-config" <<'EOF'
managed_by=oh-my-devpod
component=zsh-config
kind=configuration
artifact=/tmp/test-zshrc
EOF
: > "${shells_file}"
: > "${sudo_log}"
PATH="${fake_bin}:${PATH}" \
  OHMYDEVPOD_BREW_BIN="${fake_bin}/brew" \
  OHMYDEVPOD_TARGET_USER="test-user" \
  OHMYDEVPOD_CURRENT_SHELL="/bin/bash" \
  OHMYDEVPOD_SHELLS_FILE="${shells_file}" \
  OHMYDEVPOD_SUDO_BIN="${fake_bin}/sudo" \
  OHMYDEVPOD_STATE_DIR="${state_dir}" \
  OMD_TEST_BREW_LOG="${brew_log}" \
  OMD_TEST_ZSH_PREFIX="${zsh_prefix}" \
  OMD_TEST_SUDO_LOG="${sudo_log}" \
  bash "${repo_root}/modules/lib/postflight.sh" install >/dev/null

grep -Fqx "chsh -s ${zsh_path} test-user" "${sudo_log}" ||
  fail "install postflight should migrate an existing managed Zsh installation"

echo "shell activation tests passed"
