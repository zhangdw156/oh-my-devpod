#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() { [[ -f "${repo_root}/$1" ]] || fail "missing file: $1"; }
assert_executable() { [[ -x "${repo_root}/$1" ]] || fail "missing executable: $1"; }
assert_dir() { [[ -d "${repo_root}/$1" ]] || fail "missing directory: $1"; }
assert_absent() { [[ ! -e "${repo_root}/$1" ]] || fail "legacy path should be removed: $1"; }
assert_doc_absent() {
  local file="$1" pattern="$2"
  if rg -q "${pattern}" "${repo_root}/${file}"; then
    fail "${file} should not contain pattern: ${pattern}"
  fi
}

assert_executable install/bootstrap.sh
assert_file components.toml
assert_file crates/omd/Cargo.toml
assert_dir modules/core
assert_dir modules/tools
assert_executable modules/lib/postflight.sh
assert_absent modules/optional

assert_absent Dockerfile.devpod
assert_absent docker
assert_absent runtime

for doc in README.md README_EN.md; do
  assert_doc_absent "${doc}" 'ghcr\.io/zhangdw156'
  assert_doc_absent "${doc}" 'docker compose'
  assert_doc_absent "${doc}" 'Dockerfile\.devpod'
done
