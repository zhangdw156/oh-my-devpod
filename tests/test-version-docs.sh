#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

rg -q '`VERSION`' "${repo_root}/README.md" \
  || fail "README.md should describe VERSION as the shared version source"
rg -q '`VERSION`' "${repo_root}/README_EN.md" \
  || fail "README_EN.md should describe VERSION as the shared version source"
rg -q '`VERSION`' "${repo_root}/DEVELOPMENT.md" \
  || fail "DEVELOPMENT.md should describe VERSION as the release source of truth"
rg -q '`VERSION`' "${repo_root}/AGENTS.md" \
  || fail "AGENTS.md should mention VERSION-based image version management"
rg -q '`VERSION`' "${repo_root}/CLAUDE.md" \
  || fail "CLAUDE.md should mention VERSION-based image version management"
