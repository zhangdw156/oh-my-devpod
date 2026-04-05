#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ ! -d "${repo_root}/vendor/opencode" ]] || fail "shared vendor/opencode should not exist"
[[ ! -f "${repo_root}/config/opencode.json" ]] || fail "shared config/opencode.json should not exist"
[[ -f "${repo_root}/runtime/openpod/config/opencode.json" ]] || fail "missing openpod runtime config"
[[ -d "${repo_root}/runtime/openpod/vendor/opencode/packages/superpowers" ]] || fail "missing openpod vendored superpowers package"
[[ -d "${repo_root}/runtime/openpod/vendor/opencode/skills" ]] || fail "missing openpod vendored global skills directory"

rg -q 'openpod_vendor_dir="\$\{runtime_dir\}/openpod/vendor"' "${repo_root}/build/update-vendor-assets.sh" \
  || fail "update-vendor-assets should define the openpod runtime vendor root"
rg -q 'cp -R "\$\{openpod_opencode_dir\}/packages/superpowers/skills"' "${repo_root}/build/update-vendor-assets.sh" \
  || fail "update-vendor-assets should sync superpowers skills from the openpod runtime vendor"
