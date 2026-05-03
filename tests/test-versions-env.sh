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

# Verify Dockerfile ARG defaults match versions.env
check "Dockerfile.devpod ARG ATUIN_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG ATUIN_VERSION=${ATUIN_VERSION}"

check "Dockerfile.devpod ARG BTOP_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG BTOP_VERSION=${BTOP_VERSION}"

check "Dockerfile.devpod ARG NEOVIM_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG NEOVIM_VERSION=${NEOVIM_VERSION}"

check "Dockerfile.devpod ARG YAZI_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG YAZI_VERSION=${YAZI_VERSION}"

check "Dockerfile.devpod ARG ZELLIJ_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG ZELLIJ_VERSION=${ZELLIJ_VERSION}"

check "Dockerfile.devpod ARG PYRIGHT_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG PYRIGHT_VERSION=${PYRIGHT_VERSION}"

check "Dockerfile.devpod ARG RUFF_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG RUFF_VERSION=${RUFF_VERSION}"

check "Dockerfile.devpod ARG HARLEQUIN_VERSION" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG HARLEQUIN_VERSION=${HARLEQUIN_VERSION}"

check "Dockerfile.devpod ARG LAZYVIM_STARTER_COMMIT" \
  "${repo_root}/Dockerfile.devpod" \
  "ARG LAZYVIM_STARTER_COMMIT=${LAZYVIM_STARTER_COMMIT}"

# Verify flavor Dockerfile ARG defaults match versions.env
check "claudepod Dockerfile ARG CLAUDE_CODE_VERSION" \
  "${repo_root}/docker/claudepod/Dockerfile" \
  "ARG CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}"

check "codexpod Dockerfile ARG CODEX_VERSION" \
  "${repo_root}/docker/codexpod/Dockerfile" \
  "ARG CODEX_VERSION=${CODEX_VERSION}"

check "copilotpod Dockerfile ARG COPILOT_VERSION" \
  "${repo_root}/docker/copilotpod/Dockerfile" \
  "ARG COPILOT_VERSION=${COPILOT_VERSION}"

check "geminipod Dockerfile ARG GEMINI_VERSION" \
  "${repo_root}/docker/geminipod/Dockerfile" \
  "ARG GEMINI_VERSION=${GEMINI_VERSION}"

# Verify update-vendor-assets.sh sources versions.env
check "update-vendor-assets.sh sources versions.env" \
  "${repo_root}/build/update-vendor-assets.sh" \
  'source.*versions\.env'

echo "=== ${pass} passed, ${fail} failed ==="
[[ "${fail}" -eq 0 ]]
