#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

help_output="$(bash "${repo_root}/install/bootstrap.sh" --help)"
bootstrap_script="${repo_root}/install/bootstrap.sh"

printf '%s' "${help_output}" | rg -q -- '--flavor' || fail "bootstrap help missing --flavor"
for flavor in openpod claudepod codexpod copilotpod geminipod; do
  printf '%s' "${help_output}" | rg -q -- "${flavor}" || fail "bootstrap help missing flavor ${flavor}"
done

rm_line="$(rg -n 'rm -rf "\$\{vendor_home\}" "\$\{runtime_home\}"' "${bootstrap_script}" | cut -d: -f1 || true)"
mkdir_line="$(rg -n 'mkdir -p "\$\{runtime_home\}"' "${bootstrap_script}" | tail -n1 | cut -d: -f1 || true)"
copy_line="$(rg -n 'cp -R "\$\{repo_root\}/runtime/\$\{flavor_name\}/vendor" "\$\{runtime_vendor_home\}"' "${bootstrap_script}" | cut -d: -f1 || true)"
uv_export_line="$(rg -n 'export OHMYDEVPOD_UV_BIN="\$\{homebrew_prefix\}/bin/uv"' "${bootstrap_script}" | cut -d: -f1 || true)"
python_tools_line="$(rg -n 'bash "\$\{repo_root\}/build/install-python-dev-tools\.sh"' "${bootstrap_script}" | cut -d: -f1 || true)"

[[ -n "${rm_line}" ]] || fail "bootstrap missing runtime cleanup"
[[ -n "${mkdir_line}" ]] || fail "bootstrap missing runtime directory recreation"
[[ -n "${copy_line}" ]] || fail "bootstrap missing flavor runtime vendor copy"
(( mkdir_line > rm_line )) || fail "runtime directory must be recreated after cleanup"
(( mkdir_line < copy_line )) || fail "runtime directory must be recreated before vendor copy"
[[ -n "${uv_export_line}" ]] || fail "bootstrap missing OHMYDEVPOD_UV_BIN export"
[[ -n "${python_tools_line}" ]] || fail "bootstrap missing python dev tools install step"
(( uv_export_line < python_tools_line )) || fail "bootstrap must export OHMYDEVPOD_UV_BIN before installing python dev tools"
