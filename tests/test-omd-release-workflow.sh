#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/release-omd.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  rg -q --fixed-strings "${pattern}" "${workflow}" || fail "workflow should contain: ${pattern}"
}

assert_not_contains() {
  local pattern="$1"
  if rg -q --fixed-strings "${pattern}" "${workflow}"; then
    fail "workflow should not contain: ${pattern}"
  fi
}

[[ -f "${workflow}" ]] || fail "missing release workflow: ${workflow}"
assert_contains 'cargo build --release -p omd'
assert_contains 'omd-x86_64-unknown-linux-gnu.tar.gz'
assert_contains 'softprops/action-gh-release'
assert_not_contains 'docker/build-push-action'
assert_not_contains 'ghcr.io'
