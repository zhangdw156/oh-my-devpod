#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

legacy_paths=(
  build/install-python-dev-tools.sh
  modules/tools/python-tools.sh
  modules/tools/python-dev-tools.sh
)

for rel in "${legacy_paths[@]}"; do
  [[ ! -e "${repo_root}/${rel}" ]] \
    || fail "uv-tool-installed implementation surface should be removed: ${rel}"
done

scan_paths=(
  components.toml
  crates/omd/src
  modules
  build
  install
  config
  README.md
  Readme.osc.md
  README_EN.md
  DEVELOPMENT.md
  versions.env
  docs/environment-variables.md
  .github/workflows
)

existing_paths=()
for rel in "${scan_paths[@]}"; do
  [[ -e "${repo_root}/${rel}" ]] && existing_paths+=("${repo_root}/${rel}")
done

matches="$(
  rg -n -i \
    'python[- ]?(tools|dev[- ]tools)|pyright|ruff|harlequin|install-python-dev-tools|uv[[:space:]]+tool' \
    "${existing_paths[@]}" || true
)"

[[ -z "${matches}" ]] || {
  printf '%s\n' "${matches}" >&2
  fail "uv-tool-installed tool references remain in runtime or user-facing product surfaces"
}
