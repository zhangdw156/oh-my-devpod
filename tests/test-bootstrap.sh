#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap="${repo_root}/install/bootstrap.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_eq() {
  local expected="$1" actual="$2"
  [[ "${actual}" == "${expected}" ]] || fail "expected '${expected}', got '${actual}'"
}

assert_file() { [[ -f "$1" ]] || fail "expected file: $1"; }
assert_executable() { [[ -x "$1" ]] || fail "expected executable: $1"; }

OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1 source "${bootstrap}"

ubuntu_release="${tmp_dir}/ubuntu-24.04"
cat > "${ubuntu_release}" <<'RELEASE'
ID=ubuntu
VERSION_ID="24.04"
RELEASE

assert_eq "ubuntu-24.04" "$(omd_detect_os_release "${ubuntu_release}")"
assert_eq "omd-x86_64-unknown-linux-gnu.tar.gz" "$(omd_archive_name x86_64-unknown-linux-gnu)"
assert_eq "https://github.com/zhangdw156/oh-my-devpod/releases/latest/download/omd-x86_64-unknown-linux-gnu.tar.gz" "$(omd_release_url latest x86_64-unknown-linux-gnu)"

bad_release="${tmp_dir}/debian"
cat > "${bad_release}" <<'RELEASE'
ID=debian
VERSION_ID="12"
RELEASE
if omd_detect_os_release "${bad_release}" >/dev/null 2>&1; then
  fail "debian should be rejected"
fi

archive_root="${tmp_dir}/archive"
mkdir -p "${archive_root}"
printf '#!/usr/bin/env bash\necho omd-test\n' > "${archive_root}/omd"
chmod +x "${archive_root}/omd"
tar -czf "${tmp_dir}/omd.tar.gz" -C "${archive_root}" omd

bin_dir="${tmp_dir}/bin"
omd_install_archive "${tmp_dir}/omd.tar.gz" "${bin_dir}"
assert_executable "${bin_dir}/omd"
assert_eq "omd-test" "$(${bin_dir}/omd)"

OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
OHMYDEVPOD_SKIP_SUDO_CHECK=1 \
OHMYDEVPOD_OS_RELEASE="${ubuntu_release}" \
OHMYDEVPOD_OMD_ARCHIVE="${tmp_dir}/omd.tar.gz" \
OHMYDEVPOD_BIN_DIR="${tmp_dir}/bin2" \
bash "${bootstrap}"
assert_file "${tmp_dir}/bin2/omd"
