#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/publish-ghcr.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "${repo_root}/VERSION" ]] || fail "missing VERSION file"
[[ -f "${workflow}" ]] || fail "missing publish workflow"

version_pattern=$(cat <<'EOF'
version="$(tr -d '\n' < VERSION)"
EOF
)
rg -q --fixed-strings "${version_pattern}" "${workflow}" \
  || fail "publish workflow should read VERSION"
rg -q 'echo "version=\$version" >> "\$GITHUB_OUTPUT"' "${workflow}" \
  || fail "publish workflow should export version from VERSION"

if rg -q 'extract_tag|docker/openpod/docker-compose.yaml:oh-my-openpod|docker/claudepod/docker-compose.yaml:oh-my-claudepod|docker/codexpod/docker-compose.yaml:oh-my-codexpod' "${workflow}"; then
  fail "publish workflow should not parse compose files for version tags"
fi
