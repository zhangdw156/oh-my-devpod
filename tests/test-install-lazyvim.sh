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

assert_glob() {
  local pattern="$1"
  compgen -G "${pattern}" >/dev/null || fail "expected path matching: ${pattern}"
}

source_dir="${tmp_dir}/vendor/nvim/lazyvim-starter"
config_dir="${tmp_dir}/config/nvim"
data_dir="${tmp_dir}/data/nvim"
state_dir="${tmp_dir}/state/nvim"
cache_dir="${tmp_dir}/cache/nvim"

mkdir -p "${source_dir}/lua/config" "${config_dir}" "${data_dir}" "${state_dir}" "${cache_dir}"
printf '%s\n' '-- starter init' > "${source_dir}/init.lua"
printf '%s\n' 'return {}' > "${source_dir}/lua/config/lazy.lua"
printf '%s\n' 'old config' > "${config_dir}/custom.lua"
printf '%s\n' 'old data' > "${data_dir}/data.txt"
printf '%s\n' 'old state' > "${state_dir}/state.txt"
printf '%s\n' 'old cache' > "${cache_dir}/cache.txt"

OPENPOD_LAZYVIM_SOURCE_DIR="${source_dir}" \
OPENPOD_NVM_CONFIG_DIR="${config_dir}" \
OPENPOD_NVM_DATA_DIR="${data_dir}" \
OPENPOD_NVM_STATE_DIR="${state_dir}" \
OPENPOD_NVM_CACHE_DIR="${cache_dir}" \
bash "${repo_root}/build/install-lazyvim.sh"

assert_file "${config_dir}/init.lua"
assert_file "${config_dir}/lua/config/lazy.lua"
assert_file "${config_dir}/.openpod-managed.json"
assert_glob "${tmp_dir}/config/nvim.openpod.bak.*"
assert_glob "${tmp_dir}/data/nvim.openpod.bak.*"
assert_glob "${tmp_dir}/state/nvim.openpod.bak.*"
assert_glob "${tmp_dir}/cache/nvim.openpod.bak.*"
