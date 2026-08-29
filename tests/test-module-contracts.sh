#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/components.toml"

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

run_expect_exit() {
  local expected="$1" description="$2"
  shift 2
  local status
  set +e
  "$@" >/dev/null 2>&1
  status=$?
  set -e
  [[ "${status}" -eq "${expected}" ]] \
    || fail "expected exit ${expected} for ${description}, got ${status}"
}

check_query_contract() {
  local module="$1" query="$2" status
  set +e
  "${module}" "${query}" >/dev/null 2>&1
  status=$?
  set -e
  case "${status}" in
    0|1) ;;
    *) fail "${module} ${query} should exit 0 or 1, got ${status}" ;;
  esac
}

[[ -f "${manifest}" ]] || fail "missing component catalog: components.toml"

while IFS=$'\t' read -r rel uninstall_supported; do
  module="${repo_root}/${rel}"
  assert_executable "${module}"
  check_query_contract "${module}" status
  check_query_contract "${module}" managed
  run_expect_zero "${rel} install dry-run" "${module}" install --dry-run
  run_expect_zero "${rel} update dry-run" "${module}" update --dry-run
  if [[ "${uninstall_supported}" == "true" ]]; then
    run_expect_zero "${rel} uninstall dry-run" "${module}" uninstall --dry-run
  else
    run_expect_exit 2 "${rel} unsupported uninstall dry-run" "${module}" uninstall --dry-run
  fi
  run_expect_exit 2 "${rel} unknown action" "${module}" unsupported-action
done < <(
  python3 - "${manifest}" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    components = tomllib.load(handle)["component"]

for component in components:
    supported = component.get(
        "uninstall",
        component.get("uninstall_supported"),
    )
    if not isinstance(supported, bool):
        raise SystemExit(
            f"FAIL: {component['id']} must declare boolean uninstall support"
        )
    print(f"{component['module']}\t{str(supported).lower()}")
PY
)
