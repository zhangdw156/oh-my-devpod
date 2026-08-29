#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="${repo_root}/modules/tools/ripgrep.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

fake_brew="${tmp_dir}/brew"
cat > "${fake_brew}" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail

state="${OHMYDEVPOD_TEST_BREW_STATE}"
case "${1:-}" in
  list)
    [[ -f "${state}" ]]
    ;;
  install)
    touch "${state}"
    ;;
  upgrade)
    [[ -f "${state}" ]]
    ;;
  uses)
    [[ "${OHMYDEVPOD_TEST_BREW_USES_FAIL:-0}" != "1" ]] || exit 2
    [[ -z "${OHMYDEVPOD_TEST_BREW_DEPENDANTS:-}" ]] \
      || printf '%s\n' "${OHMYDEVPOD_TEST_BREW_DEPENDANTS}"
    ;;
  uninstall)
    rm -f "${state}"
    ;;
  *)
    exit 2
    ;;
esac
BREW
chmod +x "${fake_brew}"

managed_home="${tmp_dir}/managed-home"
managed_state="${tmp_dir}/managed-formula"
mkdir -p "${managed_home}"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" install

[[ -f "${managed_state}" ]] || fail "install should create the fake formula"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" managed

rm -f "${managed_state}"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" update
[[ -f "${managed_state}" ]] || fail "update should repair a damaged managed formula"

if env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  OHMYDEVPOD_TEST_BREW_DEPENDANTS="dependent-formula" \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should reject Homebrew formulas with installed dependants"
fi

if env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  OHMYDEVPOD_TEST_BREW_USES_FAIL=1 \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should fail closed when Homebrew dependency inspection fails"
fi
[[ -f "${managed_state}" ]] || fail "dependency inspection failure must preserve the formula"

external_home="${tmp_dir}/external-home"
external_state="${tmp_dir}/external-formula"
mkdir -p "${external_home}"
touch "${external_state}"
if env \
  HOME="${external_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${external_state}" \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should reject an external formula"
fi
[[ -f "${external_state}" ]] || fail "external formula must remain installed"
