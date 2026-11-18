#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: $0 <release.tar.gz> <package.tgz> [ubuntu-version ...]}"
package="${2:?usage: $0 <release.tar.gz> <package.tgz> [ubuntu-version ...]}"
shift 2
[[ $# -gt 0 ]] || set -- 20.04 22.04 24.04 26.04

for path in "${archive}" "${archive}.sha256" "${package}"; do
  [[ -f "${path}" ]] || { printf 'Missing test artifact: %s\n' "${path}" >&2; exit 1; }
done
archive="$(cd "$(dirname "${archive}")" && pwd)/$(basename "${archive}")"
package="$(cd "$(dirname "${package}")" && pwd)/$(basename "${package}")"
for version in "$@"; do
  case "${version}" in
    20.04|22.04|24.04|26.04) ;;
    *) printf 'Unsupported test version: %s\n' "${version}" >&2; exit 1 ;;
  esac
done

# Use the same Linux Node.js runtime even when invoked from a macOS host.
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/omd-ubuntu.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT
curl -fsSL --retry 2 --connect-timeout 15 --max-time 300 \
  https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o "${tmp_dir}/SHASUMS256.txt"
awk '$2 ~ /^node-v[0-9.]+-linux-x64.tar.xz$/ { print; exit }' \
  "${tmp_dir}/SHASUMS256.txt" > "${tmp_dir}/node.sha256"
node_archive="$(awk '{ print $2 }' "${tmp_dir}/node.sha256")"
[[ -n "${node_archive}" ]] || { echo 'Missing Node.js Linux x64 checksum' >&2; exit 1; }
node_version="${node_archive#node-}"
node_version="${node_version%-linux-x64.tar.xz}"
curl -fsSL --retry 2 --connect-timeout 15 --max-time 300 \
  "https://nodejs.org/dist/${node_version}/${node_archive}" -o "${tmp_dir}/${node_archive}"
(cd "${tmp_dir}" && sha256sum -c node.sha256)

# Run from a file so package installers cannot consume the test commands through stdin.
cat > "${tmp_dir}/compatibility.sh" <<'CONTAINER'
set -euo pipefail
source /etc/os-release
[[ "${ID}" == ubuntu && "${VERSION_ID}" == "$1" && "$(uname -m)" == x86_64 ]]
# Include the documented Linuxbrew prerequisites and the two-login test tools.
test_dependencies=(build-essential ca-certificates curl file git procps python3 sudo xz-utils zsh)
case "${VERSION_ID}" in
  # uv needs distutils to inspect Ubuntu's Python 3.8 and 3.10.
  20.04|22.04) test_dependencies+=(python3-distutils) ;;
esac
apt-get update -qq
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  "${test_dependencies[@]}" > /tmp/test-dependencies.log 2>&1; then
  cat /tmp/test-dependencies.log >&2
  exit 1
fi
mkdir -p /opt/node /tmp/bundle
tar -xJf /fixtures/node.tar.xz -C /opt/node --strip-components=1
tar -xzf /fixtures/omd.tar.gz -C /tmp/bundle
useradd --create-home --shell /bin/bash --groups sudo omd-smoke
useradd --create-home --shell /bin/bash --groups sudo omd-peer
chmod 0700 /home/omd-smoke /home/omd-peer
cat > /tmp/omd-smoke.sh <<'SMOKE'
set -euo pipefail
expected_version="$(cat /tmp/bundle/oh-my-devpod/VERSION)"
check_cli() {
  local command="$1"
  [[ "$("${command}" --version)" == "omd ${expected_version}" ]]
  "${command}" --list-components > "${HOME}/components.out"
  grep -q 'lazyvim' "${HOME}/components.out"
  "${command}" --plan install lazyvim > "${HOME}/plan.out"
  grep -q 'neovim' "${HOME}/plan.out"
  grep -q 'lazyvim' "${HOME}/plan.out"
}

for source in github gitee; do
  OHMYDEVPOD_SOURCE="${source}" \
    OHMYDEVPOD_OMD_ARCHIVE=/fixtures/omd.tar.gz \
    OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
    bash /tmp/bundle/oh-my-devpod/install/bootstrap.sh
  check_cli "${HOME}/.local/bin/omd"
  [[ "$(cat "${HOME}/.config/oh-my-devpod/source")" == "${source}" ]]

  npm_prefix="${HOME}/npm-${source}"
  OHMYDEVPOD_SOURCE="${source}" npm install --global --prefix "${npm_prefix}" \
    --offline --no-audit --no-fund /fixtures/omd.tgz
  cmp /tmp/bundle/oh-my-devpod/bin/omd \
    "${npm_prefix}/lib/node_modules/oh-my-devpod/runtime/bin/omd"
  check_cli "${npm_prefix}/bin/omd"
  [[ "$(cat "${HOME}/.config/oh-my-devpod/npm-source")" == "${source}" ]]
  if "${npm_prefix}/bin/omd" --update >"${HOME}/npm-update.out" 2>&1; then
    echo 'npm-managed omd must reject self-update' >&2
    exit 1
  fi
  grep -Fq 'npm update -g oh-my-devpod' "${HOME}/npm-update.out"
done
SMOKE
runuser -u omd-smoke -- env PATH="/opt/node/bin:${PATH}" bash /tmp/omd-smoke.sh

runuser -l omd-smoke -c '
  set -e
  omd --source github
  omd --execute install jq uv
'
runuser -l omd-peer -c '
  set -e
  OHMYDEVPOD_OMD_ARCHIVE=/fixtures/omd.tar.gz OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
    bash /tmp/bundle/oh-my-devpod/install/bootstrap.sh
  "$HOME/.local/bin/omd" --status | grep -Eq "^jq[[:space:]]+missing[[:space:]]"
  "$HOME/.local/bin/omd" --execute install jq
'

runuser -l omd-smoke -c '
  set -e
  test "$(command -v brew)" = "$HOME/.linuxbrew/bin/brew"
  test "$(brew --prefix)" = "$HOME/.linuxbrew"
  test "$(stat -c %u "$HOME/.linuxbrew")" = "$(id -u)"
  test "$(command -v jq)" = "$HOME/.linuxbrew/bin/jq"
  jq -en "1 + 1 == 2"
  test "$(command -v uv)" = "$HOME/.linuxbrew/bin/uv"
  uv venv --python /usr/bin/python3 "$HOME/.venvs/omd-smoke"
  "$HOME/.venvs/omd-smoke/bin/python" -c "import sys; assert sys.prefix != sys.base_prefix"
  test ! -x /home/omd-peer/.linuxbrew/bin/brew
'
runuser -l omd-peer -c '
  set -e
  test "$(command -v brew)" = "$HOME/.linuxbrew/bin/brew"
  test "$(brew --prefix)" = "$HOME/.linuxbrew"
  test "$(stat -c %u "$HOME/.linuxbrew")" = "$(id -u)"
  test "$(command -v jq)" = "$HOME/.linuxbrew/bin/jq"
  jq -en "2 + 2 == 4"
  test ! -x /home/omd-smoke/.linuxbrew/bin/brew
  test ! -e "$HOME/.venvs/omd-smoke"
  omd --source gitee
  test "$(git -C "$HOME/.linuxbrew" remote get-url origin)" = https://mirrors.ustc.edu.cn/brew.git
  grep -Fq https://mirrors.ustc.edu.cn "$HOME/.linuxbrew/etc/homebrew/brew.env"
  omd --source github
  omd --execute update jq
  omd --execute uninstall jq
  test ! -e "$HOME/.linuxbrew/Cellar/jq"
'
runuser -l omd-smoke -c '
  set -e
  test "$(git -C "$HOME/.linuxbrew" remote get-url origin)" = https://github.com/Homebrew/brew.git
  test ! -e "$HOME/.linuxbrew/etc/homebrew/brew.env"
  jq -en "3 + 3 == 6"
  "$HOME/.venvs/omd-smoke/bin/python" --version
'
test ! -e /usr/local/bin/brew
test ! -e /var/lib/oh-my-devpod
test ! -e /etc/sudoers.d/oh-my-devpod-brew
printf 'Ubuntu %s: bootstrap, npm, two-user Brew isolation, source switching, uninstall, and uv passed\n' "${VERSION_ID}"
CONTAINER

for version in "$@"; do
  printf '\nTesting release artifacts on Ubuntu %s x86_64\n' "${version}"
  docker run --rm --platform linux/amd64 \
    --mount "type=bind,src=${archive},dst=/fixtures/omd.tar.gz,readonly" \
    --mount "type=bind,src=${archive}.sha256,dst=/fixtures/omd.tar.gz.sha256,readonly" \
    --mount "type=bind,src=${package},dst=/fixtures/omd.tgz,readonly" \
    --mount "type=bind,src=${tmp_dir}/${node_archive},dst=/fixtures/node.tar.xz,readonly" \
    --mount "type=bind,src=${tmp_dir}/compatibility.sh,dst=/fixtures/compatibility.sh,readonly" \
    "ubuntu:${version}" bash /fixtures/compatibility.sh "${version}" | tee "${tmp_dir}/${version}.log"
  grep -Fqx "Ubuntu ${version}: bootstrap, npm, two-user Brew isolation, source switching, uninstall, and uv passed" \
    "${tmp_dir}/${version}.log"
done
