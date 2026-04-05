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

mapfile_pattern=$(cat <<'EOF'
mapfile -t version_lines < <(tr -d '\r' < VERSION)
EOF
)
rg -q --fixed-strings "${mapfile_pattern}" "${workflow}" \
  || fail "publish workflow should read VERSION"
version_line_pattern=$(cat <<'EOF'
version="${version_lines[0]:-}"
EOF
)
rg -q --fixed-strings "${version_line_pattern}" "${workflow}" \
  || fail "publish workflow should derive the version variable from VERSION"
rg -q 'echo "version=\$version" >> "\$GITHUB_OUTPUT"' "${workflow}" \
  || fail "publish workflow should export version from VERSION"
rg -q --fixed-strings '(\.dev[[:digit:]]+)?$' "${workflow}" \
  || fail "publish workflow should validate only release and .devN version formats"
for step in \
  'Set up Docker Buildx' \
  'Log in to GitHub Container Registry' \
  'Generate base Docker metadata' \
  'Build and push devpod base image' \
  'Build and push openpod image' \
  'Build and push claudepod image' \
  'Build and push codexpod image'; do
  step_gate_pattern=$(cat <<EOF
      - name: ${step}
        if: steps.version.outputs.publish == 'true'
EOF
)
  if ! grep -Fq "${step_gate_pattern}" "${workflow}"; then
    fail "workflow step '${step}' should be gated by publish == true"
  fi
done

if rg -q --fixed-strings 'docker-compose.yaml' "${workflow}"; then
  fail "publish workflow should not inspect compose files for version tags"
fi
