#!/usr/bin/env bash
set -euo pipefail

bundle_root="${OHMYDEVPOD_BUNDLE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1
# shellcheck source=bootstrap.sh
source "${bundle_root}/install/bootstrap.sh"
# shellcheck source=../modules/lib/common.sh
source "${bundle_root}/modules/lib/common.sh"

omd_update_normalize_version() {
  printf '%s\n' "${1#v}"
}

omd_update_archive_version() {
  local archive="$1" cache_dir="$2" staging_dir bundle_root version
  staging_dir="$(mktemp -d "${cache_dir}/.inspect.XXXXXX")" || return 1
  if ! tar -xzf "${archive}" -C "${staging_dir}"; then
    rm -rf "${staging_dir}"
    return 1
  fi
  bundle_root="${staging_dir}/oh-my-devpod"
  if ! omd_validate_bundle "${bundle_root}"; then
    rm -rf "${staging_dir}"
    return 1
  fi
  version="$(tr -d '[:space:]' < "${bundle_root}/VERSION")"
  rm -rf "${staging_dir}"
  [[ -n "${version}" ]] || return 1
  printf '%s\n' "${version}"
}

omd_update_snapshot_source_config() {
  local config_dir="$1" snapshot_dir="$2" name
  mkdir -p "${snapshot_dir}" || return 1
  for name in source mirror-profile env uv.toml install-prefix bin-dir cache-dir; do
    if [[ -f "${config_dir}/${name}" ]]; then
      cp -p "${config_dir}/${name}" "${snapshot_dir}/${name}" || return 1
    else
      : > "${snapshot_dir}/.missing-${name}" || return 1
    fi
  done
}

omd_update_restore_source_config() {
  local config_dir="$1" snapshot_dir="$2" name
  mkdir -p "${config_dir}" || return 1
  for name in source mirror-profile env uv.toml install-prefix bin-dir cache-dir; do
    if [[ -f "${snapshot_dir}/.missing-${name}" ]]; then
      rm -f "${config_dir}/${name}" || return 1
    else
      cat "${snapshot_dir}/${name}" |
        omd_atomic_write "${config_dir}/${name}" ||
        return 1
    fi
  done
}

OMD_UPDATE_BREW_PREFIX=""
OMD_UPDATE_BREW_REMOTE=""
OMD_UPDATE_BREW_REMOTE_PRESENT=0
OMD_UPDATE_BREW_REMOTE_CHANGED=0
OMD_UPDATE_BREW_LEGACY=0

omd_update_capture_brew_remote() {
  local marker_prefix
  omd_module_is_managed linuxbrew || return 0
  marker_prefix="$(omd_module_marker_value linuxbrew artifact || true)"
  [[ -n "${marker_prefix}" && -d "${marker_prefix}" ]] || return 0
  command -v git >/dev/null 2>&1 || {
    omd_warn "Git is required to switch the managed Homebrew remote"
    return 1
  }

  OMD_UPDATE_BREW_PREFIX="${marker_prefix}"
  if [[ ! -d "${marker_prefix}/.git" ]]; then
    OMD_UPDATE_BREW_LEGACY=1
    return 0
  fi
  if OMD_UPDATE_BREW_REMOTE="$(git -C "${marker_prefix}" remote get-url origin 2>/dev/null)"; then
    OMD_UPDATE_BREW_REMOTE_PRESENT=1
  else
    OMD_UPDATE_BREW_REMOTE=""
    OMD_UPDATE_BREW_REMOTE_PRESENT=0
  fi
}

omd_update_apply_brew_remote() {
  local source="$1" target_remote
  [[ -n "${OMD_UPDATE_BREW_PREFIX}" ]] || return 0
  target_remote="$(omd_source_brew_remote "${source}")" || return 1
  if [[ "${OMD_UPDATE_BREW_LEGACY}" == "1" ]]; then
    git -C "${OMD_UPDATE_BREW_PREFIX}" init -q || return 1
    OMD_UPDATE_BREW_REMOTE_CHANGED=1
    git -C "${OMD_UPDATE_BREW_PREFIX}" remote add origin "${target_remote}" || return 1
    return 0
  fi
  if [[ "${OMD_UPDATE_BREW_REMOTE_PRESENT}" == "1" ]]; then
    [[ "${OMD_UPDATE_BREW_REMOTE}" == "${target_remote}" ]] && return 0
    git -C "${OMD_UPDATE_BREW_PREFIX}" remote set-url origin "${target_remote}" || return 1
  else
    git -C "${OMD_UPDATE_BREW_PREFIX}" remote add origin "${target_remote}" || return 1
  fi
  OMD_UPDATE_BREW_REMOTE_CHANGED=1
}

omd_update_restore_brew_remote() {
  [[ "${OMD_UPDATE_BREW_REMOTE_CHANGED}" == "1" ]] || return 0
  if [[ "${OMD_UPDATE_BREW_LEGACY}" == "1" ]]; then
    rm -rf "${OMD_UPDATE_BREW_PREFIX}/.git"
    return
  fi
  if [[ "${OMD_UPDATE_BREW_REMOTE_PRESENT}" == "1" ]]; then
    git -C "${OMD_UPDATE_BREW_PREFIX}" remote set-url origin "${OMD_UPDATE_BREW_REMOTE}"
  else
    git -C "${OMD_UPDATE_BREW_PREFIX}" remote remove origin
  fi
}

omd_update_abort_with_rollback() {
  local message="$1" config_dir="$2" snapshot_dir="$3" rollback_failed=0
  omd_update_restore_brew_remote || rollback_failed=1
  omd_update_restore_source_config "${config_dir}" "${snapshot_dir}" || rollback_failed=1
  if [[ "${rollback_failed}" == "0" ]]; then
    rm -rf "${snapshot_dir}"
    omd_error "${message}; current installation and source were restored"
  fi
  omd_error "${message}; automatic rollback was incomplete; recovery snapshot: ${snapshot_dir}"
}

omd_update_main() {
  local requested_source="" current_source update_source current_version latest_tag latest_version
  local target prefix bin_dir cache_dir config_dir archive checksum archive_version installed_version
  local snapshot_dir="" source_changed=0 configure_source=0 manage_source=0

  case "$#" in
    0) ;;
    1)
      case "$1" in
        --github)
          requested_source="github"
          configure_source=1
          ;;
        --gitee)
          requested_source="gitee"
          configure_source=1
          ;;
        *) omd_error "Unknown self-update option: $1" ;;
      esac
      ;;
    *) omd_error "Use only one of --github or --gitee" ;;
  esac

  omd_require_linux
  omd_require_command curl
  omd_require_command tar
  omd_require_command sha256sum

  target="$(omd_target_triple)"
  prefix="${OHMYDEVPOD_PREFIX:-${OMD_DEFAULT_PREFIX}}"
  bin_dir="${OHMYDEVPOD_BIN_DIR:-${OMD_DEFAULT_BIN_DIR}}"
  cache_dir="${OHMYDEVPOD_CACHE_DIR:-${OMD_DEFAULT_CACHE_DIR}}"
  config_dir="${OHMYDEVPOD_CONFIG_DIR:-${OMD_DEFAULT_CONFIG_DIR}}"
  current_version="${OHMYDEVPOD_CURRENT_VERSION:-$(tr -d '[:space:]' < "${bundle_root}/VERSION")}"
  current_source="$(omd_read_saved_source "${config_dir}")"
  update_source="${requested_source:-${current_source}}"
  [[ "${current_source}" == "${update_source}" ]] || source_changed=1
  if [[ "${configure_source}" == "1" ]]; then
    manage_source=1
  elif omd_saved_source_is_valid "${config_dir}" &&
    omd_validate_source_config_ownership "${update_source}" "${config_dir}" >/dev/null 2>&1; then
    manage_source=1
  fi

  mkdir -p "${cache_dir}" "$(dirname "${config_dir}")"

  if [[ -n "${OHMYDEVPOD_OMD_ARCHIVE:-}" ]]; then
    archive="${OHMYDEVPOD_OMD_ARCHIVE}"
    checksum="${OHMYDEVPOD_OMD_CHECKSUM:-${archive}.sha256}"
    [[ -f "${checksum}" ]] ||
      omd_error "Local archive override requires a checksum file: ${checksum}"
    omd_verify_checksum "${archive}" "${checksum}" ||
      omd_error "Self-update checksum verification failed; current installation and source were preserved"
    latest_tag="$(omd_update_archive_version "${archive}" "${cache_dir}")" ||
      omd_error "Self-update archive validation failed; current installation and source were preserved"
  else
    latest_tag="$(omd_resolve_version "${update_source}" "${OHMYDEVPOD_VERSION:-latest}")" ||
      omd_error "Failed to query the latest ${update_source} release; current installation and source were preserved"
  fi
  latest_version="$(omd_update_normalize_version "${latest_tag}")"

  printf 'Current version: %s\n' "${current_version}"
  printf 'Current source: %s\n' "${current_source}"
  printf 'Update source: %s\n' "${update_source}"
  printf 'Latest version: %s\n' "${latest_version}"

  if [[ "$(omd_update_normalize_version "${current_version}")" != "${latest_version}" ]]; then
    if [[ -z "${OHMYDEVPOD_OMD_ARCHIVE:-}" ]]; then
      OMD_DOWNLOADED_ARCHIVE=""
      OMD_SELECTED_SOURCE=""
      omd_download_release "${update_source}" "${latest_tag}" "${target}" "${cache_dir}" ||
        omd_error "Self-update download or checksum verification failed; current installation and source were preserved"
      archive="${OMD_DOWNLOADED_ARCHIVE}"
      archive_version="$(omd_update_archive_version "${archive}" "${cache_dir}")" ||
        omd_error "Self-update archive validation failed; current installation and source were preserved"
      [[ "$(omd_update_normalize_version "${archive_version}")" == "${latest_version}" ]] ||
        omd_error "Release archive version ${archive_version} does not match ${latest_tag}; current installation and source were preserved"
    fi
  else
    archive=""
  fi

  if [[ -n "${archive}" ]]; then
    printf 'Updating omd...\n'
  fi
  if [[ "${source_changed}" == "1" ]]; then
    printf 'Switching managed software sources: %s -> %s\n' "${current_source}" "${update_source}"
  fi

  if [[ "${manage_source}" == "1" ]]; then
    if [[ "${configure_source}" == "1" ]]; then
      omd_validate_source_config_ownership "${update_source}" "${config_dir}" ||
        omd_error "Source configuration is not managed by oh-my-devpod; current installation and source were preserved"
    fi
    snapshot_dir="$(mktemp -d "${cache_dir}/.source-snapshot.XXXXXX")" ||
      omd_error "Could not prepare source configuration transaction"
    omd_update_snapshot_source_config "${config_dir}" "${snapshot_dir}" || {
      rm -rf "${snapshot_dir}"
      omd_error "Could not snapshot source configuration"
    }
    omd_update_capture_brew_remote || {
      rm -rf "${snapshot_dir}"
      omd_error "Could not inspect the managed Homebrew remote"
    }
    if ! omd_persist_source "${update_source}" "${config_dir}" "${configure_source}"; then
      omd_update_abort_with_rollback "Could not update source configuration" "${config_dir}" "${snapshot_dir}"
    fi
    if ! omd_persist_install_paths "${prefix}" "${bin_dir}" "${cache_dir}" "${config_dir}"; then
      omd_update_abort_with_rollback "Could not persist installation paths" "${config_dir}" "${snapshot_dir}"
    fi
    if ! omd_update_apply_brew_remote "${update_source}"; then
      omd_update_abort_with_rollback "Could not switch the managed Homebrew remote" "${config_dir}" "${snapshot_dir}"
    fi
  fi

  if [[ -n "${archive}" ]]; then
    if ! installed_version="$(omd_install_archive "${archive}" "${prefix}" "${bin_dir}")"; then
      if [[ "${manage_source}" == "1" ]]; then
        omd_update_abort_with_rollback "Self-update installation failed" "${config_dir}" "${snapshot_dir}"
      fi
      omd_error "Self-update installation failed; current installation and source were preserved"
    fi
    [[ -z "${snapshot_dir}" ]] || rm -rf "${snapshot_dir}"
    printf 'Successfully updated omd to %s\n' "${installed_version}"
  else
    [[ -z "${snapshot_dir}" ]] || rm -rf "${snapshot_dir}"
    printf 'omd %s is already up to date.\n' "${current_version}"
    if [[ "${configure_source}" == "1" ]]; then
      printf 'Source configuration updated successfully.\n'
    fi
  fi
}

omd_update_main "$@"
