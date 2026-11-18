#!/usr/bin/env bash
set -euo pipefail

unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
tmp="$(cd "${tmp}" && pwd -P)"
trap 'rm -rf "${tmp}"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

user_a="${tmp}/user-a"
user_b="${tmp}/user-b"
mirror_user="${tmp}/mirror-user"
source_brew="${tmp}/brew-source"
linuxbrew="${repo_root}/modules/core/linuxbrew.sh"
tool="${repo_root}/modules/tools/ripgrep.sh"
mkdir -p "${user_a}" "${user_b}" "${mirror_user}" "${source_brew}/bin" "${tmp}/bin"
cat > "${tmp}/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
printf 'unexpected sudo\n' >> "${OMD_TEST_SUDO_LOG:?}"
exit 1
SUDO
cat > "${tmp}/bin/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
  -s) printf 'Linux\n' ;;
  -m) printf 'x86_64\n' ;;
  *) exit 2 ;;
esac
UNAME
cat > "${source_brew}/bin/brew" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail
prefix="$(cd "$(dirname "$0")/.." && pwd -P)"
[[ -z "${HOMEBREW_PREFIX:-}${HOMEBREW_CACHE:-}" ]]
if IFS= read -r line; then
  printf 'Homebrew unexpectedly received caller input: %s\n' "${line}" >&2
  exit 2
fi
case "$1" in
  update)
    if [[ -n "${OMD_TEST_RUBY_SHA:-}" ]]; then
      git -C "${prefix}" checkout --quiet --detach 1.0.1
      [[ "${OMD_TEST_UPDATE_FAILURE:-}" != 1 ]] || exit 1
    fi
    touch "${prefix}/updated"
    ;;
  install) mkdir -p "${prefix}/Cellar/$2/1.0" ;;
  upgrade) touch "${prefix}/Cellar/$2/upgraded" ;;
  uses) ;;
  uninstall) rm -rf "${prefix}/Cellar/$2" ;;
  *) exit 2 ;;
esac
BREW
chmod +x "${source_brew}/bin/brew" "${tmp}/bin/sudo" "${tmp}/bin/uname"
git init -q "${source_brew}"
git -C "${source_brew}" add bin/brew
git -C "${source_brew}" -c user.name=OMD -c user.email=omd@example.invalid commit -qm fixture

run_as() {
  local home="$1"
  shift
  env HOME="${home}" PATH="${tmp}/bin:${user_a}/.linuxbrew/bin:${PATH}" \
    HOMEBREW_BREW_GIT_REMOTE="file://${source_brew}" \
    HOMEBREW_PREFIX="${user_a}/.linuxbrew" HOMEBREW_CACHE="${user_a}/.cache/Homebrew" \
    SUDO_USER=user-a OMD_TEST_SUDO_LOG="${tmp}/sudo.log" "$@"
}

run_as "${user_a}" "${linuxbrew}" install
run_as "${user_a}" bash -c '
  "$1" install
  IFS= read -r line
  [[ "${line}" == "keep this input" ]]
' _ "${tool}" <<< 'keep this input'
if run_as "${user_b}" "${linuxbrew}" status || run_as "${user_b}" "${tool}" status; then
  fail "a Brew inherited on PATH is not an installation for the current account"
fi

ln -s "${user_a}/.linuxbrew" "${user_b}/.linuxbrew"
if run_as "${user_b}" "${linuxbrew}" install; then
  fail "an alias to another user's prefix must be rejected"
fi
rm "${user_b}/.linuxbrew"

run_as "${user_b}" "${linuxbrew}" install
run_as "${user_b}" "${tool}" install
run_as "${user_b}" "${linuxbrew}" update
run_as "${user_b}" "${tool}" update
run_as "${user_b}" "${tool}" uninstall
[[ -d "${user_a}/.linuxbrew/Cellar/ripgrep/1.0" ]] || fail "B removed A's formula"
[[ ! -e "${user_a}/.linuxbrew/updated" ]] || fail "B updated A's Brew"
[[ ! -e "${user_a}/.linuxbrew/Cellar/ripgrep/upgraded" ]] || fail "B updated A's formula"
[[ ! -e "${user_b}/.linuxbrew/Cellar/ripgrep" ]] || fail "B's uninstall did not run"
[[ "$(grep -c 'oh-my-devpod Linuxbrew' "${user_b}/.profile")" == 1 ]] || fail "login activation must be idempotent"
run_as "${user_b}" bash -c 'source "${HOME}/.profile"; [[ "$(command -v brew)" == "${HOME}/.linuxbrew/bin/brew" ]]'

printf 'ID=ubuntu\nVERSION_ID=24.04\n' > "${tmp}/os-release"
run_as "${user_b}" env OHMYDEVPOD_OS_RELEASE="${tmp}/os-release" OHMYDEVPOD_CURRENT_VERSION=1.0 bash "${repo_root}/install/update.sh" --source-only --gitee
[[ "$(git -C "${user_b}/.linuxbrew" remote get-url origin)" == https://mirrors.ustc.edu.cn/brew.git ]]
[[ "$(git -C "${user_a}/.linuxbrew" remote get-url origin)" == "file://${source_brew}" ]]
[[ -f "${user_b}/.linuxbrew/etc/homebrew/brew.env" ]]
[[ ! -e "${user_a}/.linuxbrew/etc/homebrew/brew.env" ]]

cat > "${tmp}/bin/curl" <<'CURL'
#!/usr/bin/env bash
[[ "${*: -1}" == "https://mirrors.ustc.edu.cn/homebrew-bottles/v2/homebrew/core/portable-ruby/blobs/sha256:${OMD_TEST_RUBY_SHA}" ]]
CURL
chmod +x "${tmp}/bin/curl"
ruby_metadata="Library/Homebrew/vendor/portable-ruby-x86_64-linux"
mkdir -p "${source_brew}/${ruby_metadata%/*}"
printf -v old_sha '%064d' 1
printf -v new_sha '%064d' 2
commit_ruby() {
  printf 'ruby_SHA=%s\n' "$1" > "${source_brew}/${ruby_metadata}"
  git -C "${source_brew}" add "${ruby_metadata}"
  git -C "${source_brew}" -c user.name=OMD -c user.email=omd@example.invalid commit -qm "portable Ruby $1"
  git -C "${source_brew}" rev-parse HEAD
}
old_revision="$(commit_ruby "${old_sha}")"
new_revision="$(commit_ruby "${new_sha}")"
git -C "${source_brew}" tag 1.0.1 "${new_revision}"
run_mirror_brew() {
  local checksum="$1"
  shift
  run_as "${mirror_user}" env OHMYDEVPOD_MIRROR_PROFILE=cn \
    OMD_TEST_RUBY_SHA="${checksum}" "$@"
}
mirror_prefix="${mirror_user}/.linuxbrew"
run_mirror_brew "${old_sha}" "${linuxbrew}" install
[[ "$(git -C "${mirror_prefix}" rev-parse HEAD)" == "${old_revision}" ]]
commit_ruby "${old_sha}" >/dev/null
run_mirror_brew "${old_sha}" "${linuxbrew}" update
[[ ! -e "${mirror_prefix}/updated" ]]
if run_mirror_brew "${new_sha}" env OMD_TEST_UPDATE_FAILURE=1 "${linuxbrew}" update; then
  fail "a failed update must report an error"
fi
[[ "$(git -C "${mirror_prefix}" rev-parse HEAD)" == "${old_revision}" ]]
run_mirror_brew "${new_sha}" "${linuxbrew}" update
[[ "$(git -C "${mirror_prefix}" rev-parse HEAD)" == "${new_revision}" ]]
[[ ! -e "${tmp}/sudo.log" ]] || fail "private lifecycle used sudo"

printf 'personal Linuxbrew tests passed\n'
