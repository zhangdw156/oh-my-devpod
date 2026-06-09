#!/usr/bin/env bash
# oh-my-devpod host installer bootstrap.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
set -euo pipefail

OMD_OWNER="zhangdw156"
OMD_REPO="oh-my-devpod"
OMD_DEFAULT_BIN_DIR="${HOME}/.local/bin"
OMD_DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/oh-my-devpod"

omd_info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
omd_warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
omd_error() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

omd_detect_os_release() {
  local os_release="$1"
  [[ -f "${os_release}" ]] || omd_error "Missing os-release file: ${os_release}"

  local ID="" VERSION_ID=""
  # shellcheck disable=SC1090
  source "${os_release}"

  if [[ "${ID}" == "ubuntu" && "${VERSION_ID}" == "24.04" ]]; then
    printf 'ubuntu-24.04\n'
    return 0
  fi

  printf 'Unsupported Linux distribution: ID=%s VERSION_ID=%s. oh-my-devpod supports Ubuntu 24.04 only.\n' \
    "${ID:-unknown}" "${VERSION_ID:-unknown}" >&2
  return 1
}

omd_target_triple() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64|amd64) printf 'x86_64-unknown-linux-gnu\n' ;;
    aarch64|arm64) printf 'aarch64-unknown-linux-gnu\n' ;;
    *) omd_error "Unsupported CPU architecture: ${machine}" ;;
  esac
}

omd_archive_name() {
  local target="$1"
  printf 'omd-%s.tar.gz\n' "${target}"
}

omd_release_url() {
  local version="$1" target="$2" archive
  archive="$(omd_archive_name "${target}")"
  if [[ "${version}" == "latest" ]]; then
    printf 'https://github.com/%s/%s/releases/latest/download/%s\n' "${OMD_OWNER}" "${OMD_REPO}" "${archive}"
  else
    printf 'https://github.com/%s/%s/releases/download/%s/%s\n' "${OMD_OWNER}" "${OMD_REPO}" "${version}" "${archive}"
  fi
}

omd_download_archive() {
  local url="$1" dest="$2"
  omd_info "Downloading omd from ${url}"
  curl -fL --connect-timeout 10 --max-time 300 "${url}" -o "${dest}"
}

omd_install_archive() {
  local archive="$1" bin_dir="$2" tmp_dir
  [[ -f "${archive}" ]] || omd_error "Missing omd archive: ${archive}"

  tmp_dir="$(mktemp -d)"
  tar -xzf "${archive}" -C "${tmp_dir}" omd
  [[ -f "${tmp_dir}/omd" ]] || omd_error "Archive does not contain omd binary at its root"
  chmod +x "${tmp_dir}/omd"
  mkdir -p "${bin_dir}"
  mv "${tmp_dir}/omd" "${bin_dir}/omd"
  rm -rf "${tmp_dir}"
}

omd_require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || omd_error "This installer supports Linux only."
}

omd_require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || omd_error "Missing required command: ${cmd}"
}

omd_require_sudo() {
  if [[ "${OHMYDEVPOD_SKIP_SUDO_CHECK:-0}" == "1" ]]; then
    return 0
  fi
  omd_require_command sudo
  omd_info "Checking sudo access; enter your password if prompted."
  sudo -v || omd_error "sudo access is required for Ubuntu package prerequisites."
}

omd_main() {
  local os_release target version bin_dir cache_dir archive url

  omd_require_linux
  omd_require_command curl
  omd_require_command tar

  os_release="${OHMYDEVPOD_OS_RELEASE:-/etc/os-release}"
  omd_detect_os_release "${os_release}" >/dev/null
  omd_require_sudo

  bin_dir="${OHMYDEVPOD_BIN_DIR:-${OMD_DEFAULT_BIN_DIR}}"
  cache_dir="${OHMYDEVPOD_CACHE_DIR:-${OMD_DEFAULT_CACHE_DIR}}"
  mkdir -p "${bin_dir}" "${cache_dir}"

  if [[ -n "${OHMYDEVPOD_OMD_ARCHIVE:-}" ]]; then
    archive="${OHMYDEVPOD_OMD_ARCHIVE}"
  else
    target="$(omd_target_triple)"
    version="${OHMYDEVPOD_VERSION:-latest}"
    archive="${cache_dir}/$(omd_archive_name "${target}")"
    url="${OHMYDEVPOD_OMD_URL:-$(omd_release_url "${version}" "${target}")}"
    omd_download_archive "${url}" "${archive}"
  fi

  omd_install_archive "${archive}" "${bin_dir}"
  omd_info "Installed omd to ${bin_dir}/omd"

  case ":${PATH}:" in
    *":${bin_dir}:"*) ;;
    *) omd_warn "${bin_dir} is not on PATH yet. Add it to your shell profile or restart the shell after setup." ;;
  esac

  if [[ "${OHMYDEVPOD_BOOTSTRAP_NO_RUN:-0}" == "1" ]]; then
    return 0
  fi

  exec "${bin_dir}/omd"
}

if [[ "${OHMYDEVPOD_BOOTSTRAP_LIB_ONLY:-0}" != "1" ]]; then
  omd_main "$@"
fi
