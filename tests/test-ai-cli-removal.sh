#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

legacy_paths=(
  build/install-claude-code.sh
  modules/optional/claude-code.sh
  modules/optional/codex.sh
  modules/optional/opencode.sh
  modules/optional/copilot.sh
  modules/optional/gemini.sh
)

for rel in "${legacy_paths[@]}"; do
  [[ ! -e "${repo_root}/${rel}" ]] \
    || fail "AI CLI implementation surface should be removed: ${rel}"
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
  CLAUDE.md
  versions.env
  docs/environment-variables.md
  docs/vendor-assets.md
  .github/workflows
)

existing_paths=()
for rel in "${scan_paths[@]}"; do
  [[ -e "${repo_root}/${rel}" ]] && existing_paths+=("${repo_root}/${rel}")
done

matches="$(
  rg -n -i \
    'claude[ -]?code|codex([[:space:]]+cli)?|opencode|copilot([[:space:]]+cli)?|gemini([[:space:]]+cli)?' \
    "${existing_paths[@]}" || true
)"

[[ -z "${matches}" ]] || {
  printf '%s\n' "${matches}" >&2
  fail "AI CLI references remain in runtime or user-facing product surfaces"
}
