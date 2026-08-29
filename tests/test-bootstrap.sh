#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap="${repo_root}/install/bootstrap.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" path="$2"
  grep -Fq "${needle}" "${path}" || fail "expected '${needle}' in ${path}"
}

assert_executable() {
  local path="$1"
  [[ -x "${path}" ]] || fail "expected executable: ${path}"
}

[[ -f "${bootstrap}" ]] || fail "missing bootstrap: install/bootstrap.sh"
assert_contains 'OHMYDEVPOD_SOURCE' "${bootstrap}"
assert_contains 'github' "${bootstrap}"
assert_contains 'gitee' "${bootstrap}"
assert_contains 'sha256' "${bootstrap}"
assert_contains '/dev/tty' "${bootstrap}"
assert_contains '/releases/' "${bootstrap}"

payload_root="${tmp_dir}/payload/oh-my-devpod"
mkdir -p \
  "${payload_root}/bin" \
  "${payload_root}/modules" \
  "${payload_root}/build" \
  "${payload_root}/config" \
  "${payload_root}/vendor"
cat > "${payload_root}/bin/omd" <<'OMD'
#!/usr/bin/env bash
printf 'omd-test\n'
OMD
chmod +x "${payload_root}/bin/omd"
printf 'schema_version = 1\n' > "${payload_root}/components.toml"
printf '1.2.3\n' > "${payload_root}/VERSION"
printf 'TEST_VERSION=1\n' > "${payload_root}/versions.env"
printf 'module\n' > "${payload_root}/modules/marker"
printf 'build\n' > "${payload_root}/build/marker"
printf 'config\n' > "${payload_root}/config/marker"
printf 'vendor\n' > "${payload_root}/vendor/marker"

archive="${tmp_dir}/omd-x86_64-unknown-linux-gnu.tar.gz"
tar -czf "${archive}" -C "${tmp_dir}/payload" oh-my-devpod
checksum="${tmp_dir}/omd-x86_64-unknown-linux-gnu.tar.gz.sha256"
(
  cd "${tmp_dir}"
  sha256sum "$(basename "${archive}")" > "$(basename "${checksum}")"
)

fake_bin="${tmp_dir}/fake-bin"
mkdir -p "${fake_bin}"
ubuntu_release="${tmp_dir}/ubuntu-os-release"
cat > "${ubuntu_release}" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
EOF
cat > "${fake_bin}/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'x86_64\n' ;;
  *) printf 'Linux\n' ;;
esac
EOF
chmod +x "${fake_bin}/uname"

cat > "${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${OHMYDEVPOD_TEST_CURL_LOG}"

destination=""
url=""
head_request=0
while (($#)); do
  case "$1" in
    -o|--output)
      destination="$2"
      shift 2
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    -I|--head)
      head_request=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "${OHMYDEVPOD_TEST_FAIL_GITHUB:-0}" == "1" && "${url}" == *github.com* ]]; then
  exit 22
fi

(( head_request == 0 )) || exit 0

source_file="${OHMYDEVPOD_TEST_ARCHIVE}"
case "${url}" in
  *.sha256*|*SHA256SUMS*) source_file="${OHMYDEVPOD_TEST_CHECKSUM}" ;;
esac

if [[ -n "${destination}" ]]; then
  cp "${source_file}" "${destination}"
else
  cat "${source_file}"
fi
EOF
chmod +x "${fake_bin}/curl"

run_bootstrap() {
  local source="$1" home="$2" log="$3" checksum_file="${4:-${checksum}}"
  local fail_github="${5:-0}"
  mkdir -p "${home}"
  PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${home}" \
  OHMYDEVPOD_OS_RELEASE="${ubuntu_release}" \
  OHMYDEVPOD_SOURCE="${source}" \
  OHMYDEVPOD_VERSION="1.2.3" \
  OHMYDEVPOD_SKIP_SUDO_CHECK=1 \
  OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
  OHMYDEVPOD_TEST_ARCHIVE="${archive}" \
  OHMYDEVPOD_TEST_CHECKSUM="${checksum_file}" \
  OHMYDEVPOD_TEST_CURL_LOG="${log}" \
  OHMYDEVPOD_TEST_FAIL_GITHUB="${fail_github}" \
    bash "${bootstrap}"
}

github_home="${tmp_dir}/github-home"
github_log="${tmp_dir}/github-curl.log"
run_bootstrap github "${github_home}" "${github_log}"
assert_contains 'github.com' "${github_log}"
assert_contains 'github' "${github_home}/.config/oh-my-devpod/source"
assert_contains 'upstream' "${github_home}/.config/oh-my-devpod/mirror-profile"
[[ ! -e "${github_home}/.config/oh-my-devpod/uv.toml" ]] \
  || fail "GitHub source should not create the managed China uv mirror"
assert_executable "${github_home}/.local/bin/omd"
[[ -L "${github_home}/.local/bin/omd" ]] \
  || fail "bootstrap should activate omd with a symlink"
github_target="$(readlink "${github_home}/.local/bin/omd")"
[[ "${github_target}" == *"/releases/"*"/bin/omd" ]] \
  || fail "omd symlink should point into a versioned release: ${github_target}"
release_manifest="$(
  find "${github_home}/.local/share/oh-my-devpod/releases" \
    -mindepth 2 -maxdepth 2 -name components.toml -print -quit
)"
[[ -n "${release_manifest}" ]] || fail "versioned release should contain components.toml"
release_root="$(dirname "${release_manifest}")"
[[ -f "${release_root}/modules/marker" ]] \
  || fail "versioned release should contain modules"
printf '#!/usr/bin/env bash\nprintf compromised\n' > "${release_root}/bin/omd"
run_bootstrap github "${github_home}" "${github_log}"
grep -Fq 'omd-test' "${release_root}/bin/omd" \
  || fail "a verified archive should replace an existing same-version release"

gitee_home="${tmp_dir}/gitee-home"
gitee_log="${tmp_dir}/gitee-curl.log"
run_bootstrap gitee "${gitee_home}" "${gitee_log}"
assert_contains 'gitee.com' "${gitee_log}"
assert_contains 'gitee' "${gitee_home}/.config/oh-my-devpod/source"
assert_contains 'cn' "${gitee_home}/.config/oh-my-devpod/mirror-profile"
assert_contains 'mirrors.ustc.edu.cn' "${gitee_home}/.config/oh-my-devpod/env"
assert_contains 'UV_CONFIG_FILE' "${gitee_home}/.config/oh-my-devpod/env"
assert_contains 'mirrors.tuna.tsinghua.edu.cn' "${gitee_home}/.config/oh-my-devpod/uv.toml"

auto_home="${tmp_dir}/auto-home"
auto_log="${tmp_dir}/auto-curl.log"
run_bootstrap auto "${auto_home}" "${auto_log}"
assert_contains 'github.com' "${auto_log}"

fallback_home="${tmp_dir}/fallback-home"
fallback_log="${tmp_dir}/fallback-curl.log"
run_bootstrap auto "${fallback_home}" "${fallback_log}" "${checksum}" 1
assert_contains 'github.com' "${fallback_log}"
assert_contains 'gitee.com' "${fallback_log}"
assert_contains 'cn' "${fallback_home}/.config/oh-my-devpod/mirror-profile"
assert_executable "${fallback_home}/.local/bin/omd"

bad_checksum="${tmp_dir}/bad.sha256"
printf '%064d  %s\n' 0 "$(basename "${archive}")" > "${bad_checksum}"
bad_home="${tmp_dir}/bad-home"
bad_log="${tmp_dir}/bad-curl.log"
if run_bootstrap github "${bad_home}" "${bad_log}" "${bad_checksum}" >/dev/null 2>&1; then
  fail "bootstrap should reject an archive with a mismatched checksum"
fi
[[ ! -e "${bad_home}/.local/bin/omd" ]] \
  || fail "checksum failure must not activate omd"

invalid_home="${tmp_dir}/invalid-home"
invalid_log="${tmp_dir}/invalid-curl.log"
if run_bootstrap invalid "${invalid_home}" "${invalid_log}" >/dev/null 2>&1; then
  fail "bootstrap should reject OHMYDEVPOD_SOURCE values outside auto|github|gitee"
fi

unchecked_archive="${tmp_dir}/unchecked.tar.gz"
cp "${archive}" "${unchecked_archive}"
unchecked_home="${tmp_dir}/unchecked-home"
if PATH="${fake_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="${unchecked_home}" \
  OHMYDEVPOD_OS_RELEASE="${ubuntu_release}" \
  OHMYDEVPOD_SOURCE=github \
  OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
  OHMYDEVPOD_OMD_ARCHIVE="${unchecked_archive}" \
  bash "${bootstrap}" >/dev/null 2>&1; then
  fail "local archive overrides must require a checksum"
fi
