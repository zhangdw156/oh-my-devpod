#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHMYDEVPOD_REPO_ROOT:?missing OHMYDEVPOD_REPO_ROOT}"
bin_dir="${OHMYDEVPOD_BIN_DIR:?missing OHMYDEVPOD_BIN_DIR}"
config_home="${OHMYDEVPOD_CONFIG_HOME:?missing OHMYDEVPOD_CONFIG_HOME}"
runtime_vendor_home="${OHMYDEVPOD_RUNTIME_VENDOR_HOME:?missing OHMYDEVPOD_RUNTIME_VENDOR_HOME}"
prefix="${OHMYDEVPOD_PREFIX:?missing OHMYDEVPOD_PREFIX}"
shell_dir="${OHMYDEVPOD_SHELL_DIR:?missing OHMYDEVPOD_SHELL_DIR}"
openpod_vendor_home="${runtime_vendor_home}/opencode"

if [[ ! -d "${openpod_vendor_home}" ]]; then
  echo "missing openpod runtime vendor at ${openpod_vendor_home}" >&2
  exit 1
fi

mkdir -p "${config_home}/plugins"
cp "${repo_root}/runtime/openpod/config/opencode.json" "${config_home}/config.json"
ln -sfn "${openpod_vendor_home}/packages/superpowers/.opencode/plugins/superpowers.js" "${config_home}/plugins/superpowers.js"
ln -sfn "${openpod_vendor_home}/skills" "${config_home}/skills"

need_opencode_install=0
if [[ ! -x "${bin_dir}/opencode" ]]; then
  need_opencode_install=1
elif ! "${bin_dir}/opencode" --version >/dev/null 2>&1; then
  need_opencode_install=1
fi

if [[ "${need_opencode_install}" == "1" ]]; then
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "openpod bootstrap requires node and npm to be preinstalled" >&2
    exit 1
  fi
  opencode_prefix="${prefix}/opt/opencode-cli"
  mkdir -p "${opencode_prefix}"
  npm install -g --prefix "${opencode_prefix}" opencode-ai@1.3.13
  ln -sfn "${opencode_prefix}/bin/opencode" "${bin_dir}/opencode"
fi

install -m 0755 "${repo_root}/runtime/openpod/bin/openpod-shell" "${bin_dir}/openpod-shell"
