#!/usr/bin/env bash
set -euo pipefail

uv_bin="${OPENPOD_UV_BIN:-uv}"
bin_dir="${OPENPOD_BIN_DIR:-/usr/local/bin}"
tool_dir="${OPENPOD_UV_TOOL_DIR:-/opt/uv-tools}"
pyright_version="${OPENPOD_PYRIGHT_VERSION:-1.1.408}"
ruff_version="${OPENPOD_RUFF_VERSION:-0.15.9}"

mkdir -p "${bin_dir}" "${tool_dir}"

UV_TOOL_BIN_DIR="${bin_dir}" \
UV_TOOL_DIR="${tool_dir}" \
"${uv_bin}" tool install --force "pyright[nodejs]==${pyright_version}"

UV_TOOL_BIN_DIR="${bin_dir}" \
UV_TOOL_DIR="${tool_dir}" \
"${uv_bin}" tool install --force "ruff==${ruff_version}"

test -e "${bin_dir}/pyright"
test -e "${bin_dir}/pyright-langserver"
test -e "${bin_dir}/ruff"
