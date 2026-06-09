#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
versions_env="${repo_root}/versions.env"
pass=0
fail=0

check() {
  local label="$1" file="$2" pattern="$3"
  if rg -q "${pattern}" "${file}"; then
    pass=$((pass + 1))
  else
    echo "FAIL: ${label} — expected pattern '${pattern}' in ${file}"
    fail=$((fail + 1))
  fi
}

echo "=== test-versions-env ==="

# versions.env must exist and be sourceable
if [[ ! -f "${versions_env}" ]]; then
  echo "FAIL: versions.env not found at ${versions_env}"
  exit 1
fi
# shellcheck source=../versions.env
source "${versions_env}"

# Verify install script fallback defaults match versions.env
check "install-atuin.sh fallback" \
  "${repo_root}/build/install-atuin.sh" \
  "ATUIN_VERSION:-${ATUIN_VERSION}"

check "install-btop.sh fallback" \
  "${repo_root}/build/install-btop.sh" \
  "BTOP_VERSION:-${BTOP_VERSION}"

check "install-zellij.sh fallback" \
  "${repo_root}/build/install-zellij.sh" \
  "ZELLIJ_VERSION:-${ZELLIJ_VERSION}"

check "install-yazi.sh fallback" \
  "${repo_root}/build/install-yazi.sh" \
  "YAZI_VERSION:-${YAZI_VERSION}"

check "install-neovim.sh fallback" \
  "${repo_root}/build/install-neovim.sh" \
  "NEOVIM_VERSION:-${NEOVIM_VERSION}"

check "install-antidote.sh fallback" \
  "${repo_root}/build/install-antidote.sh" \
  "ANTIDOTE_VERSION:-${ANTIDOTE_VERSION}"

check "install-witr.sh fallback" \
  "${repo_root}/build/install-witr.sh" \
  "WITR_VERSION:-${WITR_VERSION}"

# Dockerfile ARG checks were removed with the Docker/flavor product surface.

# Verify update-vendor-assets.sh sources versions.env
check "update-vendor-assets.sh sources versions.env" \
  "${repo_root}/build/update-vendor-assets.sh" \
  'source.*versions\.env'

echo "=== ${pass} passed, ${fail} failed ==="
[[ "${fail}" -eq 0 ]]
