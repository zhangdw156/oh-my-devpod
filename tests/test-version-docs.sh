#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_contains() {
  local file="$1"
  local term="$2"
  local message="$3"

  if ! rg -q --fixed-strings "$term" "$file"; then
    fail "$message"
  fi
}

check_no_compose_source_truth() {
  local file="$1"
  if rg -q 'compose.*source of truth' "$file" && ! rg -q 'compose.*not.*source of truth' "$file"; then
    fail "$(basename "$file") should not describe compose files as the version source of truth"
  fi
}

check_contains "${repo_root}/README.md" '`VERSION`' "README.md should describe VERSION as the shared version source"
check_contains "${repo_root}/README_EN.md" '`VERSION`' "README_EN.md should describe VERSION as the shared version source"
check_contains "${repo_root}/DEVELOPMENT.md" '`VERSION`' "DEVELOPMENT.md should describe VERSION as the release source of truth"
check_contains "${repo_root}/AGENTS.md" '`VERSION`' "AGENTS.md should mention VERSION-based image version management"
check_contains "${repo_root}/CLAUDE.md" '`VERSION`' "CLAUDE.md should mention VERSION-based image version management"

check_contains "${repo_root}/README.md" 'IMAGE_VERSION' "README.md should describe the IMAGE_VERSION consumption model"
check_contains "${repo_root}/README_EN.md" 'IMAGE_VERSION' "README_EN.md should describe the IMAGE_VERSION consumption model"
check_contains "${repo_root}/DEVELOPMENT.md" 'IMAGE_VERSION' "DEVELOPMENT.md should describe the IMAGE_VERSION consumption model"
check_contains "${repo_root}/CLAUDE.md" 'IMAGE_VERSION' "CLAUDE.md should describe the IMAGE_VERSION consumption model"
check_contains "${repo_root}/DEVELOPMENT.md" '不会自动读取 `VERSION`' "DEVELOPMENT.md should state that compose does not read VERSION automatically"
check_contains "${repo_root}/CLAUDE.md" 'do not read `VERSION` automatically' "CLAUDE.md should state that compose does not read VERSION automatically"
check_contains "${repo_root}/DEVELOPMENT.md" 'export' "DEVELOPMENT.md should explain how to inject IMAGE_VERSION from VERSION"
check_contains "${repo_root}/CLAUDE.md" 'export' "CLAUDE.md should explain how to inject IMAGE_VERSION from VERSION"

check_no_compose_source_truth "${repo_root}/README.md"
check_no_compose_source_truth "${repo_root}/README_EN.md"
check_no_compose_source_truth "${repo_root}/CLAUDE.md"
