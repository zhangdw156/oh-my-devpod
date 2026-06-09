#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_root}/build/update-vendor-assets.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ ! -e "${repo_root}/vendor/opencode" ]] || fail "shared vendor/opencode should not exist"
[[ ! -e "${repo_root}/runtime" ]] || fail "legacy runtime directory should not exist"

for term in runtime/ openpod claudepod codexpod copilotpod geminipod; do
  if rg -q --fixed-strings "${term}" "${script}"; then
    fail "update-vendor-assets.sh should not mention legacy term: ${term}"
  fi
done

rg -q --fixed-strings 'vendor_dir}/zsh' "${script}" \
  || fail "update-vendor-assets.sh should still refresh vendor/zsh"
rg -q --fixed-strings 'vendor_dir}/nvim/lazyvim-starter' "${script}" \
  || fail "update-vendor-assets.sh should still refresh LazyVim starter"
