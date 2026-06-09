#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_contains() {
  local file="$1" term="$2" message="$3"
  rg -q --fixed-strings "$term" "$file" || fail "$message"
}

check_absent() {
  local file="$1" pattern="$2" message="$3"
  if rg -q "$pattern" "$file"; then
    fail "$message"
  fi
}

for file in README.md README_EN.md DEVELOPMENT.md AGENTS.md CLAUDE.md; do
  path="${repo_root}/${file}"
  check_contains "${path}" '`VERSION`' "${file} should describe VERSION as the release source"
  check_contains "${path}" 'omd' "${file} should describe omd"
  check_contains "${path}" 'install/bootstrap.sh' "${file} should describe install/bootstrap.sh"
  check_contains "${path}" 'cargo test -p omd' "${file} should include omd test command"
  check_absent "${path}" 'IMAGE_VERSION' "${file} should not describe IMAGE_VERSION"
  check_absent "${path}" 'ghcr\.io/zhangdw156' "${file} should not advertise GHCR images"
  check_absent "${path}" 'docker compose' "${file} should not advertise docker compose"
done
