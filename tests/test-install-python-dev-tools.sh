#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "expected file: ${path}"
}

assert_contains() {
  local needle="$1"
  local path="$2"
  grep -Fq "${needle}" "${path}" || fail "expected '${needle}' in ${path}"
}

bin_dir="${tmp_dir}/bin"
tool_dir="${tmp_dir}/tools"
log_file="${tmp_dir}/uv.log"
fake_uv="${tmp_dir}/fake-uv"

cat > "${fake_uv}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'UV_TOOL_BIN_DIR=%s\n' "${UV_TOOL_BIN_DIR:-}" >> "${OHMYDEVPOD_UV_LOG}"
printf 'UV_TOOL_DIR=%s\n' "${UV_TOOL_DIR:-}" >> "${OHMYDEVPOD_UV_LOG}"
printf 'ARGS=%s\n' "$*" >> "${OHMYDEVPOD_UV_LOG}"
mkdir -p "${UV_TOOL_BIN_DIR}"
case "$*" in
  *pyright*)
    : > "${UV_TOOL_BIN_DIR}/pyright"
    : > "${UV_TOOL_BIN_DIR}/pyright-langserver"
    ;;
  *ruff*)
    : > "${UV_TOOL_BIN_DIR}/ruff"
    ;;
  *harlequin*)
    : > "${UV_TOOL_BIN_DIR}/harlequin"
    ;;
esac
EOF
chmod +x "${fake_uv}"

OHMYDEVPOD_UV_BIN="${fake_uv}" \
OHMYDEVPOD_UV_LOG="${log_file}" \
OHMYDEVPOD_BIN_DIR="${bin_dir}" \
OHMYDEVPOD_UV_TOOL_DIR="${tool_dir}" \
bash "${repo_root}/build/install-python-dev-tools.sh"

assert_file "${bin_dir}/pyright"
assert_file "${bin_dir}/pyright-langserver"
assert_file "${bin_dir}/ruff"
assert_file "${bin_dir}/harlequin"
assert_contains "UV_TOOL_BIN_DIR=${bin_dir}" "${log_file}"
assert_contains "UV_TOOL_DIR=${tool_dir}" "${log_file}"
assert_contains "ARGS=tool install --force pyright[nodejs]==1.1.408" "${log_file}"
assert_contains "ARGS=tool install --force ruff==0.15.9" "${log_file}"
assert_contains "ARGS=tool install --force harlequin==2.5.2" "${log_file}"
