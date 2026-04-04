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
printf 'UV_TOOL_BIN_DIR=%s\n' "${UV_TOOL_BIN_DIR:-}" >> "${OPENPOD_UV_LOG}"
printf 'UV_TOOL_DIR=%s\n' "${UV_TOOL_DIR:-}" >> "${OPENPOD_UV_LOG}"
printf 'ARGS=%s\n' "$*" >> "${OPENPOD_UV_LOG}"
mkdir -p "${UV_TOOL_BIN_DIR}"
case "$*" in
  *pyright*)
    : > "${UV_TOOL_BIN_DIR}/pyright"
    : > "${UV_TOOL_BIN_DIR}/pyright-langserver"
    ;;
  *ruff*)
    : > "${UV_TOOL_BIN_DIR}/ruff"
    ;;
esac
EOF
chmod +x "${fake_uv}"

OPENPOD_UV_BIN="${fake_uv}" \
OPENPOD_UV_LOG="${log_file}" \
OPENPOD_BIN_DIR="${bin_dir}" \
OPENPOD_UV_TOOL_DIR="${tool_dir}" \
bash "${repo_root}/build/install-python-dev-tools.sh"

assert_file "${bin_dir}/pyright"
assert_file "${bin_dir}/pyright-langserver"
assert_file "${bin_dir}/ruff"
assert_contains "UV_TOOL_BIN_DIR=${bin_dir}" "${log_file}"
assert_contains "UV_TOOL_DIR=${tool_dir}" "${log_file}"
assert_contains "ARGS=tool install --force pyright[nodejs]==1.1.408" "${log_file}"
assert_contains "ARGS=tool install --force ruff==0.15.9" "${log_file}"
