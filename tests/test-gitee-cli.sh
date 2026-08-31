#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="${repo_root}/modules/tools/gitee.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

file_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

make_release() {
  local version="$1" reported_version="${2:-$1}" release_dir staging arch archive checksum
  release_dir="${tmp_dir}/releases/download/v${version}"
  mkdir -p "${release_dir}"

  for arch in amd64 arm64; do
    staging="${tmp_dir}/staging-${version}-${arch}"
    rm -rf "${staging}"
    mkdir -p "${staging}"
    cat > "${staging}/gitee" <<EOF
#!/usr/bin/env bash
printf 'gitee ${reported_version} ${arch}\n'
EOF
    chmod +x "${staging}/gitee"
    archive="gitee_${version}_linux_${arch}.tar.gz"
    tar -czf "${release_dir}/${archive}" -C "${staging}" gitee
  done

  : > "${release_dir}/checksums.txt"
  for archive in "${release_dir}"/gitee_*.tar.gz; do
    checksum="$(sha256_file "${archive}")"
    printf '%s  ./%s\n' "${checksum}" "$(basename "${archive}")" \
      >> "${release_dir}/checksums.txt"
  done
}

write_latest_release() {
  local version="$1" api_file release_dir
  api_file="${tmp_dir}/api/v5/repos/oschina/gitee-cli/releases/latest"
  release_dir="${tmp_dir}/releases/download/v${version}"
  mkdir -p "$(dirname "${api_file}")"
  cat > "${api_file}" <<EOF
{
  "tag_name": "v${version}",
  "assets": [
    {
      "name": "gitee_${version}_linux_amd64.tar.gz",
      "browser_download_url": "file://${release_dir}/gitee_${version}_linux_amd64.tar.gz"
    },
    {
      "name": "gitee_${version}_linux_arm64.tar.gz",
      "browser_download_url": "file://${release_dir}/gitee_${version}_linux_arm64.tar.gz"
    },
    {
      "name": "checksums.txt",
      "browser_download_url": "file://${release_dir}/checksums.txt"
    }
  ]
}
EOF
}

run_module() {
  local home="$1" arch="$2"
  shift 2
  env \
    HOME="${home}" \
    PATH="/usr/bin:/bin" \
    TARGETARCH="${arch}" \
    OHMYDEVPOD_BIN_DIR="${home}/.local/bin" \
    OHMYDEVPOD_GITEE_CLI_API_BASE="file://${tmp_dir}/api/v5" \
    OHMYDEVPOD_GITEE_CLI_RELEASE_BASE="file://${tmp_dir}/releases/download" \
    OHMYDEVPOD_STATE_DIR="${home}/.local/state/oh-my-devpod" \
    "${module}" "$@"
}

run_module_with_state() {
  local home="$1" arch="$2" state_dir="$3"
  shift 3
  env \
    HOME="${home}" \
    PATH="/usr/bin:/bin" \
    TARGETARCH="${arch}" \
    OHMYDEVPOD_BIN_DIR="${home}/.local/bin" \
    OHMYDEVPOD_GITEE_CLI_API_BASE="file://${tmp_dir}/api/v5" \
    OHMYDEVPOD_GITEE_CLI_RELEASE_BASE="file://${tmp_dir}/releases/download" \
    OHMYDEVPOD_STATE_DIR="${state_dir}" \
    "${module}" "$@"
}

make_release 1.2.3
make_release 1.2.4
write_latest_release 1.2.3

managed_home="${tmp_dir}/managed-home"
managed_bin="${managed_home}/.local/bin/gitee"
managed_marker="${managed_home}/.local/state/oh-my-devpod/managed/gitee"
managed_config="${managed_home}/.config/gitee"
mkdir -p "${managed_config}"
printf 'host: gitee.com\n' > "${managed_config}/config.yml"
printf 'credential sentinel\n' > "${managed_config}/credentials.yml"
chmod 600 "${managed_config}/credentials.yml"
config_hash_before="$(sha256_file "${managed_config}/config.yml")"
credentials_hash_before="$(sha256_file "${managed_config}/credentials.yml")"

run_module "${managed_home}" x86_64 install >/dev/null
[[ -x "${managed_bin}" ]] || fail "install should create the managed Gitee CLI binary"
[[ "$("${managed_bin}")" == "gitee 1.2.3 amd64" ]] ||
  fail "x86_64 should select the amd64 release asset"
grep -Fqx 'managed_by=oh-my-devpod' "${managed_marker}" ||
  fail "install should create an ownership marker"
grep -Fqx "artifact=${managed_bin}" "${managed_marker}" ||
  fail "marker should record the managed binary"
grep -Eq '^binary_sha256=[[:xdigit:]]{64}$' "${managed_marker}" ||
  fail "marker should record the installed binary checksum"
run_module "${managed_home}" amd64 status
run_module "${managed_home}" amd64 managed

binary_hash_before="$(sha256_file "${managed_bin}")"
marker_hash_before="$(sha256_file "${managed_marker}")"
write_latest_release 1.2.4
printf 'invalid checksum  ./gitee_1.2.4_linux_amd64.tar.gz\n' \
  > "${tmp_dir}/releases/download/v1.2.4/checksums.txt"
if run_module "${managed_home}" amd64 update >/dev/null 2>&1; then
  fail "checksum failure should reject a Gitee CLI update"
fi
[[ "$(sha256_file "${managed_bin}")" == "${binary_hash_before}" ]] ||
  fail "failed update should preserve the active binary"
[[ "$(sha256_file "${managed_marker}")" == "${marker_hash_before}" ]] ||
  fail "failed update should preserve the ownership marker"

make_release 1.2.4
run_module "${managed_home}" amd64 update >/dev/null
[[ "$("${managed_bin}")" == "gitee 1.2.4 amd64" ]] ||
  fail "update should atomically replace the managed binary"
[[ "$(sha256_file "${managed_config}/config.yml")" == "${config_hash_before}" ]] ||
  fail "update should preserve Gitee CLI configuration"
[[ "$(sha256_file "${managed_config}/credentials.yml")" == "${credentials_hash_before}" ]] ||
  fail "update should preserve Gitee CLI credentials"
[[ "$(file_mode "${managed_config}/credentials.yml")" == "600" ]] ||
  fail "update should preserve credential permissions"

arm_home="${tmp_dir}/arm-home"
write_latest_release 1.2.3
run_module "${arm_home}" aarch64 install >/dev/null
[[ "$("${arm_home}/.local/bin/gitee")" == "gitee 1.2.3 arm64" ]] ||
  fail "aarch64 should select the arm64 release asset"

unsupported_home="${tmp_dir}/unsupported-home"
if run_module "${unsupported_home}" ppc64le install >/dev/null 2>&1; then
  fail "unsupported architectures should be rejected"
fi
[[ ! -e "${unsupported_home}/.local/bin/gitee" ]] ||
  fail "unsupported architecture should not create a binary"

bad_home="${tmp_dir}/bad-home"
printf 'invalid checksum  ./gitee_1.2.3_linux_amd64.tar.gz\n' \
  > "${tmp_dir}/releases/download/v1.2.3/checksums.txt"
if run_module "${bad_home}" amd64 install >/dev/null 2>&1; then
  fail "checksum failure should reject a fresh install"
fi
[[ ! -e "${bad_home}/.local/bin/gitee" ]] ||
  fail "failed install should not activate a binary"
[[ ! -e "${bad_home}/.local/state/oh-my-devpod/managed/gitee" ]] ||
  fail "failed install should not create a marker"
make_release 1.2.3

wrong_version_home="${tmp_dir}/wrong-version-home"
make_release 1.2.5 1.2.50
write_latest_release 1.2.5
if run_module "${wrong_version_home}" amd64 install >/dev/null 2>&1; then
  fail "near-matching version output should be rejected"
fi
[[ ! -e "${wrong_version_home}/.local/bin/gitee" ]] ||
  fail "version validation failure should not activate a binary"

marker_failure_home="${tmp_dir}/marker-failure-home"
blocked_state="${marker_failure_home}/blocked-state"
mkdir -p "${marker_failure_home}"
printf 'not a directory\n' > "${blocked_state}"
write_latest_release 1.2.3
if run_module_with_state \
  "${marker_failure_home}" \
  amd64 \
  "${blocked_state}" \
  install >/dev/null 2>&1; then
  fail "marker write failure should reject the install"
fi
[[ ! -e "${marker_failure_home}/.local/bin/gitee" ]] ||
  fail "marker write failure should roll back the installed binary"

external_home="${tmp_dir}/external-home"
external_bin="${external_home}/.local/bin/gitee"
mkdir -p "$(dirname "${external_bin}")"
printf '#!/usr/bin/env bash\nprintf "external gitee\\n"\n' > "${external_bin}"
chmod +x "${external_bin}"
external_hash="$(sha256_file "${external_bin}")"
run_module "${external_home}" amd64 install >/dev/null
[[ "$(sha256_file "${external_bin}")" == "${external_hash}" ]] ||
  fail "install should preserve an external Gitee CLI binary"
[[ ! -e "${external_home}/.local/state/oh-my-devpod/managed/gitee" ]] ||
  fail "external Gitee CLI should not receive an ownership marker"
if run_module "${external_home}" amd64 uninstall >/dev/null 2>&1; then
  fail "uninstall should reject an external Gitee CLI binary"
fi
[[ "$(sha256_file "${external_bin}")" == "${external_hash}" ]] ||
  fail "external Gitee CLI should remain after rejected uninstall"

replaced_home="${tmp_dir}/replaced-home"
write_latest_release 1.2.3
run_module "${replaced_home}" amd64 install >/dev/null
replaced_bin="${replaced_home}/.local/bin/gitee"
printf '#!/usr/bin/env bash\nprintf "replacement gitee\\n"\n' > "${replaced_bin}"
chmod +x "${replaced_bin}"
replaced_hash="$(sha256_file "${replaced_bin}")"
if run_module "${replaced_home}" amd64 managed >/dev/null 2>&1; then
  fail "a replaced binary should no longer count as managed"
fi
run_module "${replaced_home}" amd64 status ||
  fail "a replaced binary should remain visible as an external installation"
run_module "${replaced_home}" amd64 update >/dev/null
[[ "$(sha256_file "${replaced_bin}")" == "${replaced_hash}" ]] ||
  fail "update should preserve a replaced Gitee CLI binary"
if run_module "${replaced_home}" amd64 uninstall >/dev/null 2>&1; then
  fail "uninstall should reject a replaced Gitee CLI binary"
fi
[[ "$(sha256_file "${replaced_bin}")" == "${replaced_hash}" ]] ||
  fail "uninstall should preserve a replaced Gitee CLI binary"

run_module "${managed_home}" amd64 uninstall >/dev/null
[[ ! -e "${managed_bin}" ]] || fail "uninstall should remove the managed binary"
[[ ! -e "${managed_marker}" ]] || fail "uninstall should remove the ownership marker"
[[ "$(sha256_file "${managed_config}/config.yml")" == "${config_hash_before}" ]] ||
  fail "uninstall should preserve Gitee CLI configuration"
[[ "$(sha256_file "${managed_config}/credentials.yml")" == "${credentials_hash_before}" ]] ||
  fail "uninstall should preserve Gitee CLI credentials"

echo "Gitee CLI tests passed"
