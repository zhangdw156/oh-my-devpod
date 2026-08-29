#!/usr/bin/env bash
# oh-my-devpod host installer bootstrap.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
set -euo pipefail

OMD_OWNER="${OHMYDEVPOD_RELEASE_OWNER:-zhangdw156}"
OMD_REPO="${OHMYDEVPOD_RELEASE_REPO:-oh-my-devpod}"
OMD_DEFAULT_BIN_DIR="${HOME}/.local/bin"
OMD_DEFAULT_PREFIX="${XDG_DATA_HOME:-${HOME}/.local/share}/oh-my-devpod"
OMD_DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/oh-my-devpod"
OMD_DEFAULT_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/oh-my-devpod"

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
    *) omd_error "Unsupported CPU architecture: ${machine}. The current release supports x86_64 Linux only." ;;
  esac
}

omd_archive_name() {
  local target="$1"
  printf 'omd-%s.tar.gz\n' "${target}"
}

omd_release_api_url() {
  local source="$1"
  case "${source}" in
    github) printf 'https://api.github.com/repos/%s/%s/releases/latest\n' "${OMD_OWNER}" "${OMD_REPO}" ;;
    gitee) printf 'https://gitee.com/api/v5/repos/%s/%s/releases/latest\n' "${OMD_OWNER}" "${OMD_REPO}" ;;
    *) return 1 ;;
  esac
}

omd_parse_tag_name() {
  sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

omd_resolve_version() {
  local source="$1" requested_version="$2" response tag
  if [[ "${requested_version}" != "latest" ]]; then
    printf '%s\n' "${requested_version}"
    return 0
  fi

  response="$(curl -fsSL --connect-timeout 10 --max-time 60 "$(omd_release_api_url "${source}")")" \
    || return 1
  tag="$(printf '%s' "${response}" | omd_parse_tag_name)"
  [[ -n "${tag}" ]] || return 1
  printf '%s\n' "${tag}"
}

omd_release_url() {
  local source version target archive
  if (($# == 2)); then
    source="github"
    version="$1"
    target="$2"
  else
    source="$1"
    version="$2"
    target="$3"
  fi
  archive="$(omd_archive_name "${target}")"

  case "${source}" in
    github)
      if [[ "${version}" == "latest" ]]; then
        printf 'https://github.com/%s/%s/releases/latest/download/%s\n' \
          "${OMD_OWNER}" "${OMD_REPO}" "${archive}"
      else
        printf 'https://github.com/%s/%s/releases/download/%s/%s\n' \
          "${OMD_OWNER}" "${OMD_REPO}" "${version}" "${archive}"
      fi
      ;;
    gitee)
      [[ "${version}" != "latest" ]] || return 1
      printf 'https://gitee.com/%s/%s/releases/download/%s/%s\n' \
        "${OMD_OWNER}" "${OMD_REPO}" "${version}" "${archive}"
      ;;
    *) return 1 ;;
  esac
}

omd_download_file() {
  local url="$1" dest="$2"
  curl -fL --connect-timeout 10 --max-time 300 "${url}" -o "${dest}"
}

omd_verify_checksum() {
  local archive="$1" checksum_file="$2" expected actual
  if [[ ! -f "${checksum_file}" ]]; then
    omd_warn "Missing checksum file: ${checksum_file}"
    return 1
  fi

  expected="$(awk 'NR == 1 { print $1 }' "${checksum_file}")"
  if [[ ! "${expected}" =~ ^[[:xdigit:]]{64}$ ]]; then
    omd_warn "Invalid SHA256 checksum file: ${checksum_file}"
    return 1
  fi
  actual="$(sha256sum "${archive}" | awk '{ print $1 }')"
  if [[ "${actual}" != "${expected}" ]]; then
    omd_warn "SHA256 verification failed for $(basename "${archive}")"
    return 1
  fi
}

omd_validate_bundle() {
  local root="$1" required
  for required in \
    bin/omd \
    components.toml \
    modules \
    build \
    config \
    vendor \
    VERSION \
    versions.env; do
    [[ -e "${root}/${required}" ]] || omd_error "Release bundle is missing ${required}"
  done
  [[ -x "${root}/bin/omd" ]] || chmod 0755 "${root}/bin/omd"
}

omd_install_archive() {
  local archive="$1" prefix="$2" bin_dir="${3:-${OMD_DEFAULT_BIN_DIR}}"
  local releases_dir staging_dir bundle_root version release_dir previous_dir link_tmp
  [[ -f "${archive}" ]] || omd_error "Missing omd archive: ${archive}"

  releases_dir="${prefix}/releases"
  mkdir -p "${releases_dir}" "${bin_dir}"
  staging_dir="$(mktemp -d "${releases_dir}/.install.XXXXXX")"
  tar -xzf "${archive}" -C "${staging_dir}"
  bundle_root="${staging_dir}/oh-my-devpod"
  omd_validate_bundle "${bundle_root}"

  version="$(tr -d '[:space:]' < "${bundle_root}/VERSION")"
  [[ -n "${version}" && "${version}" != */* && "${version}" != "." && "${version}" != ".." ]] \
    || omd_error "Release bundle contains an invalid VERSION"
  release_dir="${releases_dir}/${version}"

  if [[ -e "${release_dir}" ]]; then
    previous_dir="${releases_dir}/.${version}.previous.$$"
    mv "${release_dir}" "${previous_dir}"
    if ! mv "${bundle_root}" "${release_dir}"; then
      mv "${previous_dir}" "${release_dir}"
      omd_error "Failed to replace existing release ${version}"
    fi
    rm -rf "${previous_dir}"
  else
    mv "${bundle_root}" "${release_dir}"
  fi
  rm -rf "${staging_dir}"

  link_tmp="${bin_dir}/.omd.$$.tmp"
  ln -s "${release_dir}/bin/omd" "${link_tmp}"
  mv -f "${link_tmp}" "${bin_dir}/omd"
  printf '%s\n' "${version}"
}

omd_require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || omd_error "This installer supports Linux only."
}

omd_require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || omd_error "Missing required command: ${cmd}"
}

omd_download_release() {
  local source="$1" requested_version="$2" target="$3" cache_dir="$4"
  local resolved_version archive_name archive checksum archive_url
  resolved_version="$(omd_resolve_version "${source}" "${requested_version}")" || return 1
  archive_name="$(omd_archive_name "${target}")"
  archive="${cache_dir}/${source}-${resolved_version}-${archive_name}"
  checksum="${archive}.sha256"
  archive_url="${OHMYDEVPOD_OMD_URL:-$(omd_release_url "${source}" "${resolved_version}" "${target}")}"

  omd_info "Downloading ${archive_name} from ${source}"
  omd_download_file "${archive_url}" "${archive}" || return 1
  omd_download_file "${OHMYDEVPOD_OMD_CHECKSUM_URL:-${archive_url}.sha256}" "${checksum}" || return 1
  omd_verify_checksum "${archive}" "${checksum}" || return 1

  OMD_DOWNLOADED_ARCHIVE="${archive}"
  OMD_SELECTED_SOURCE="${source}"
}

omd_persist_source() {
  local source="$1" config_dir="$2" mirror_profile env_file
  mirror_profile="upstream"
  [[ "${source}" != "gitee" ]] || mirror_profile="cn"
  mkdir -p "${config_dir}"
  printf '%s\n' "${source}" > "${config_dir}/source"
  printf '%s\n' "${mirror_profile}" > "${config_dir}/mirror-profile"
  env_file="${config_dir}/env"
  {
    printf '# Generated by oh-my-devpod. Re-run bootstrap to change the source profile.\n'
    printf 'export OHMYDEVPOD_MIRROR_PROFILE=%q\n' "${mirror_profile}"
    if [[ "${mirror_profile}" == "cn" ]]; then
      printf '%s\n' \
        'export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"' \
        'export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"' \
        'export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"' \
        'export UV_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod/uv.toml"'
    fi
  } > "${env_file}"

  if [[ "${mirror_profile}" == "cn" ]]; then
    cat > "${config_dir}/uv.toml" <<'EOF'
[[index]]
url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"
default = true
EOF
  else
    rm -f "${config_dir}/uv.toml"
  fi
}

omd_main() {
  local os_release target requested_version source bin_dir prefix cache_dir config_dir
  local archive checksum selected_source installed_version candidate

  omd_require_linux
  omd_require_command curl
  omd_require_command tar
  omd_require_command sha256sum

  os_release="${OHMYDEVPOD_OS_RELEASE:-/etc/os-release}"
  omd_detect_os_release "${os_release}" >/dev/null
  source="${OHMYDEVPOD_SOURCE:-auto}"
  case "${source}" in
    auto|github|gitee) ;;
    *) omd_error "OHMYDEVPOD_SOURCE must be one of: auto, github, gitee" ;;
  esac

  target="$(omd_target_triple)"
  requested_version="${OHMYDEVPOD_VERSION:-latest}"
  bin_dir="${OHMYDEVPOD_BIN_DIR:-${OMD_DEFAULT_BIN_DIR}}"
  prefix="${OHMYDEVPOD_PREFIX:-${OMD_DEFAULT_PREFIX}}"
  cache_dir="${OHMYDEVPOD_CACHE_DIR:-${OMD_DEFAULT_CACHE_DIR}}"
  config_dir="${OHMYDEVPOD_CONFIG_DIR:-${OMD_DEFAULT_CONFIG_DIR}}"
  mkdir -p "${bin_dir}" "${prefix}/releases" "${cache_dir}"

  selected_source="${source}"
  if [[ -n "${OHMYDEVPOD_OMD_ARCHIVE:-}" ]]; then
    archive="${OHMYDEVPOD_OMD_ARCHIVE}"
    checksum="${OHMYDEVPOD_OMD_CHECKSUM:-${archive}.sha256}"
    [[ -f "${checksum}" ]] \
      || omd_error "Local archive override requires a checksum file: ${checksum}"
    omd_verify_checksum "${archive}" "${checksum}" \
      || omd_error "Local archive checksum verification failed"
    [[ "${selected_source}" != "auto" ]] || selected_source="github"
  else
    OMD_DOWNLOADED_ARCHIVE=""
    OMD_SELECTED_SOURCE=""
    if [[ "${source}" == "auto" ]]; then
      for candidate in github gitee; do
        if omd_download_release "${candidate}" "${requested_version}" "${target}" "${cache_dir}"; then
          break
        fi
        omd_warn "Could not download a verified release from ${candidate}; trying the next source."
      done
    else
      omd_download_release "${source}" "${requested_version}" "${target}" "${cache_dir}" \
        || omd_error "Could not download a verified release from ${source}"
    fi
    [[ -n "${OMD_DOWNLOADED_ARCHIVE}" ]] \
      || omd_error "Could not download a verified oh-my-devpod release"
    archive="${OMD_DOWNLOADED_ARCHIVE}"
    selected_source="${OMD_SELECTED_SOURCE}"
  fi

  installed_version="$(omd_install_archive "${archive}" "${prefix}" "${bin_dir}")"
  omd_persist_source "${selected_source}" "${config_dir}"
  omd_info "Installed oh-my-devpod ${installed_version} from ${selected_source}"
  omd_info "Activated omd at ${bin_dir}/omd"

  case ":${PATH}:" in
    *":${bin_dir}:"*) ;;
    *) omd_warn "${bin_dir} is not on PATH yet. Add it to your shell profile or restart the shell after setup." ;;
  esac

  if [[ "${OHMYDEVPOD_BOOTSTRAP_NO_RUN:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 && -r /dev/tty && -w /dev/tty ]]; then
    exec "${bin_dir}/omd" "$@" </dev/tty >/dev/tty 2>/dev/tty
  fi
  exec "${bin_dir}/omd" "$@"
}

if [[ "${OHMYDEVPOD_BOOTSTRAP_LIB_ONLY:-0}" != "1" ]]; then
  omd_main "$@"
fi
