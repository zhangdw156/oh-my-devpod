#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
setup_script="${repo_root}/install/setup.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  grep -Fq "${needle}" "${setup_script}" || fail "expected '${needle}' in install/setup.sh"
}

assert_not_contains() {
  local needle="$1"
  if grep -Fq "${needle}" "${setup_script}"; then
    fail "did not expect '${needle}' in install/setup.sh"
  fi
}

assert_contains 'using domestic mirrors (USTC Homebrew, TUNA PyPI, npmmirror npm)'
assert_contains 'export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"'
assert_not_contains 'HOMEBREW_CORE_GIT_REMOTE'
assert_contains 'export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"'
assert_contains 'export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"'
assert_not_contains 'mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git'
assert_not_contains 'mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git'
assert_not_contains 'mirrors.tuna.tsinghua.edu.cn/homebrew-bottles'
