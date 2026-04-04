#!/usr/bin/env bash
set -euo pipefail

source_dir="${OPENPOD_LAZYVIM_SOURCE_DIR:-/opt/vendor/nvim/lazyvim-starter}"
config_dir="${OPENPOD_NVM_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/nvim}"
data_dir="${OPENPOD_NVM_DATA_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/nvim}"
state_dir="${OPENPOD_NVM_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/nvim}"
cache_dir="${OPENPOD_NVM_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/nvim}"
marker_name="${OPENPOD_MANAGED_MARKER:-.openpod-managed.json}"
marker_path="${config_dir}/${marker_name}"
starter_commit="${OPENPOD_LAZYVIM_STARTER_COMMIT:-}"
openpod_version="${OPENPOD_VERSION:-unknown}"
timestamp="$(date -u +%Y%m%d%H%M%SZ)"

if [[ ! -d "${source_dir}" ]]; then
  echo "LazyVim source directory not found: ${source_dir}" >&2
  exit 1
fi

if [[ -z "${starter_commit}" && -f "${source_dir}/.openpod-source-commit" ]]; then
  starter_commit="$(<"${source_dir}/.openpod-source-commit")"
fi

if [[ -z "${starter_commit}" ]]; then
  starter_commit="unknown"
fi

backup_path_if_exists() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    mv "${path}" "${path}.openpod.bak.${timestamp}"
  fi
}

is_managed_install() {
  [[ -f "${marker_path}" ]] && grep -q '"managed_by":[[:space:]]*"openpod"' "${marker_path}"
}

if is_managed_install; then
  rm -rf "${config_dir}"
else
  backup_path_if_exists "${config_dir}"
  backup_path_if_exists "${data_dir}"
  backup_path_if_exists "${state_dir}"
  backup_path_if_exists "${cache_dir}"
fi

mkdir -p "$(dirname "${config_dir}")"
cp -R "${source_dir}" "${config_dir}"
rm -rf "${config_dir}/.git"
rm -f "${config_dir}/.openpod-source-commit"

cat > "${marker_path}" <<EOF
{
  "managed_by": "openpod",
  "starter_commit": "${starter_commit}",
  "installed_at": "${timestamp}",
  "openpod_version": "${openpod_version}"
}
EOF
