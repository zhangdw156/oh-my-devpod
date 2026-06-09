#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_executable() {
  local path="$1"
  [[ -x "${path}" ]] || fail "expected executable module: ${path}"
}

run_expect_zero() {
  local description="$1"
  shift
  "$@" >/dev/null || fail "expected success: ${description}"
}

run_expect_nonzero() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: ${description}"
  fi
}

check_status_contract() {
  local module="$1" status_code
  set +e
  "${module}" status >/dev/null 2>&1
  status_code=$?
  set -e
  case "${status_code}" in
    0|1) ;;
    *) fail "${module} status should exit 0 or 1, got ${status_code}" ;;
  esac
}

required_modules=(
  modules/core/brew.sh
  modules/core/zsh.sh
  modules/core/base-tools.sh
)

optional_modules=(
  modules/optional/claude-code.sh
  modules/optional/codex.sh
  modules/optional/opencode.sh
  modules/optional/copilot.sh
  modules/optional/gemini.sh
)

for rel in "${required_modules[@]}" "${optional_modules[@]}"; do
  module="${repo_root}/${rel}"
  assert_executable "${module}"
  check_status_contract "${module}"
  run_expect_zero "${rel} install dry-run" "${module}" install --dry-run
  run_expect_zero "${rel} update dry-run" "${module}" update --dry-run
  run_expect_nonzero "${rel} unknown action" "${module}" unsupported-action

done

for rel in "${required_modules[@]}"; do
  module="${repo_root}/${rel}"
  run_expect_nonzero "${rel} required uninstall dry-run" "${module}" uninstall --dry-run
done

for rel in "${optional_modules[@]}"; do
  module="${repo_root}/${rel}"
  run_expect_zero "${rel} optional uninstall dry-run" "${module}" uninstall --dry-run
done
