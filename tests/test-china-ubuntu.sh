#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="${1:?usage: $0 <release.tar.gz> [Ubuntu version ...]}"
shift
[[ $# -gt 0 ]] || set -- 26.04 20.04 22.04 24.04
archive="$(cd "$(dirname "${archive}")" && pwd)/$(basename "${archive}")"
[[ -f "${archive}" && -f "${archive}.sha256" ]]
tmp="$(mktemp -d)"
chmod 0755 "${tmp}"
proxy="omd-china-proxy-$$"
network="omd-china-test-$$"

cleanup() {
  if [[ "$?" != 0 ]]; then
    docker logs "${proxy}" >&2 || true
  fi
  docker rm -f "${proxy}" >/dev/null 2>&1 || true
  docker network rm "${network}" >/dev/null 2>&1 || true
  rm -rf "${tmp}"
}
trap cleanup EXIT
cp "${archive}" "${tmp}/omd.tar.gz"
cp "${archive}.sha256" "${tmp}/omd.tar.gz.sha256"
docker network create --internal "${network}" >/dev/null
docker run --detach --name "${proxy}" \
  --mount "type=bind,src=${repo_root}/tests/china-mirror-proxy.py,dst=/proxy.py,readonly" \
  python:3.12-alpine python /proxy.py >/dev/null
docker network connect --alias china-proxy "${network}" "${proxy}"
for attempt in {1..20}; do
  if docker exec "${proxy}" python -c 'import socket; socket.create_connection(("127.0.0.1", 8080), 1).close()' >/dev/null 2>&1; then
    break
  fi
  if [[ "${attempt}" == 20 ]]; then
    printf 'The domestic HTTPS test proxy did not start.\n' >&2
    exit 1
  fi
  sleep 1
done
docker cp "${proxy}:/etc/ssl/certs/ca-certificates.crt" "${tmp}/ca-certificates.crt"

cat > "${tmp}/account.sh" <<'ACCOUNT'
#!/usr/bin/env bash
set -euo pipefail
export OHMYDEVPOD_SOURCE=gitee
export OHMYDEVPOD_OMD_ARCHIVE=/fixtures/omd.tar.gz
export OHMYDEVPOD_BOOTSTRAP_NO_RUN=1
# Both containers send their traffic through one proxy and mirror.
export HOMEBREW_DOWNLOAD_CONCURRENCY=4
bash /tmp/omd-bundle/oh-my-devpod/install/bootstrap.sh
omd="${HOME}/.local/bin/omd"
[[ "$(cat "${HOME}/.config/oh-my-devpod/source")" == gitee ]]
if [[ "$1" == all ]]; then
  mapfile -t components < <("${omd}" --list-components | cut -f1)
  "${omd}" --execute install "${components[@]}"
else
  "${omd}" --status | grep -Eq '^jq[[:space:]]+missing[[:space:]]'
  "${omd}" --execute install jq
fi
export PATH="${HOME}/.linuxbrew/bin:${HOME}/.local/bin:${PATH}"
test "$(brew --prefix)" = "${HOME}/.linuxbrew"
jq -en '1 + 1 == 2'
if [[ "$1" == all ]]; then
  for command in uv micromamba git gh gitee rg fzf bat fd yq atuin zellij yazi btop witr nvim zsh; do
    "${command}" --version
  done
  mkdir -p "${HOME}/disk-probe/example"
  printf 'disk usage probe\n' > "${HOME}/disk-probe/example/sample.txt"
  (cd "${HOME}/disk-probe" && dust .) > "${HOME}/dust.out"
  grep -Fq 'example' "${HOME}/dust.out"
  uv venv --python 3.12.12 "${HOME}/.venvs/mirror-probe"
  uv pip install --python "${HOME}/.venvs/mirror-probe/bin/python" idna
  "${HOME}/.venvs/mirror-probe/bin/python" -c 'import idna'
  micromamba create --quiet --yes --prefix "${HOME}/.local/share/mamba-probe" --override-channels -c conda-forge zlib
  nvim --headless '+lua if type(LazyVim) ~= "table" then vim.cmd("cquit") end' +qa
  script -qec "zsh -ic '[[ \${POWERLEVEL9K_DISABLE_GITSTATUS:-} == true ]]'" /dev/null
  "${omd}" --execute update linuxbrew gitee lazyvim zsh-config
  "${omd}" --update
else
  "${omd}" --execute update jq
  "${omd}" --execute uninstall jq
  test ! -e "${HOME}/.linuxbrew/Cellar/jq"
fi
ACCOUNT

cat > "${tmp}/container.sh" <<'CONTAINER'
#!/usr/bin/env bash
set -euo pipefail
source /etc/os-release
[[ "${VERSION_ID}" == "$1" && "$(uname -m)" == x86_64 ]]
export https_proxy=http://china-proxy:8080
export http_proxy="${https_proxy}"
export HTTPS_PROXY="${https_proxy}"
export HTTP_PROXY="${https_proxy}"
install -Dm 0644 /fixtures/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
shopt -s nullglob
for sources in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  [[ -f "${sources}" ]] || continue
  sed -Ei 's@https?://([[:alnum:].-]+\.)?ubuntu\.com/ubuntu/?@https://mirrors.ustc.edu.cn/ubuntu/@g' "${sources}"
done
apt_options=(-o Acquire::Retries=2 -o Acquire::https::CaInfo=/fixtures/ca-certificates.crt)
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update -qq
DEBIAN_FRONTEND=noninteractive apt-get "${apt_options[@]}" install -y -qq --no-install-recommends \
  build-essential ca-certificates curl file git openssh-client openssh-server procps sudo > /tmp/test-dependencies.log 2>&1 || {
  cat /tmp/test-dependencies.log >&2
  exit 1
}
test "$(curl -sS --max-time 10 --noproxy '*' -o /dev/null -w '%{http_code}' https://mirrors.ustc.edu.cn/ 2>/dev/null || true)" = 000
mkdir -p /tmp/omd-bundle
tar -xzf /fixtures/omd.tar.gz -C /tmp/omd-bundle
curl -fsSL --retry 2 https://gitee.com/api/v5/repos/zhangdw156/oh-my-devpod/releases/latest | grep '"tag_name"' >/dev/null
useradd -m -s /bin/bash -G sudo mirror-a
useradd -m -s /bin/bash -G sudo mirror-b
chmod 0700 /home/mirror-a /home/mirror-b
runuser -u mirror-a -- bash /fixtures/account.sh all
runuser -u mirror-b -- bash /fixtures/account.sh peer

# Exercise real SSH login, remote commands and file transfer in the two disposable accounts.
mkdir -p /run/sshd
ssh-keygen -q -t ed25519 -N '' -f /tmp/omd-client-key
for account in mirror-a mirror-b; do
  install -d -m 0700 -o "${account}" -g "${account}" "/home/${account}/.ssh"
  install -m 0600 -o "${account}" -g "${account}" /tmp/omd-client-key.pub "/home/${account}/.ssh/authorized_keys"
done
/usr/sbin/sshd -p 2222 -o ListenAddress=127.0.0.1 -o PasswordAuthentication=no -o AuthenticationMethods=publickey
ssh_options=(-i /tmp/omd-client-key -o Port=2222 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
check_login() {
  local account="$1" expected="$2" log="/tmp/login-$1.log" expected_shell=/bin/bash
  if [[ "${expected}" == zsh ]]; then
    expected_shell="/home/${account}/.linuxbrew/bin/zsh"
  fi
  if ! TERM=xterm timeout 45 ssh -tt "${ssh_options[@]}" "${account}@127.0.0.1" >"${log}" 2>&1 <<'PROBE'
if test -n "${ZSH_VERSION:-}" && test -r "${ZSH:-/missing}/oh-my-zsh.sh" && test "$HOME/.linuxbrew/bin/zsh" -ef /proc/$$/exe; then active=zsh; elif test -n "${BASH_VERSION:-}"; then active=bash; else active=unknown; fi
printf '\nOMD-LOGIN=%s,%s\n' "$active" "$(printenv SHELL)"
exit
PROBE
  then
    cat "${log}"
    return 1
  fi
  grep -Fq "OMD-LOGIN=${expected},${expected_shell}" "${log}" || { cat "${log}"; return 1; }
}
check_login mirror-a zsh
check_login mirror-b bash
ssh "${ssh_options[@]}" mirror-a@127.0.0.1 'test -n "$BASH_VERSION" && test -z "${ZSH_VERSION:-}" && test "$(printenv SHELL)" = /bin/bash'
sftp -b - "${ssh_options[@]}" mirror-a@127.0.0.1 <<< 'get .profile /tmp/received-profile'
cmp /tmp/received-profile /home/mirror-a/.profile
runuser -u mirror-a -- /home/mirror-a/.local/bin/omd --execute uninstall zsh-config
check_login mirror-a bash
check_login mirror-b bash
runuser -u mirror-a -- /home/mirror-a/.linuxbrew/bin/jq -en '2 + 2 == 4'
test ! -e /usr/local/bin/brew
printf 'Ubuntu %s: domestic-only Gitee installation passed\n' "${VERSION_ID}"
CONTAINER

run_version() {
  local version="$1"
  case "${version}" in 20.04|22.04|24.04|26.04) ;; *) exit 2 ;; esac
  docker run --rm --platform linux/amd64 --network "${network}" \
    --mount "type=bind,src=${tmp},dst=/fixtures,readonly" \
    "ubuntu:${version}" bash /fixtures/container.sh "${version}" 2>&1 |
    tee "${tmp}/${version}.log" | sed -u "s/^/[${version}] /"
  grep -Fqx "Ubuntu ${version}: domestic-only Gitee installation passed" "${tmp}/${version}.log"
}

pids=()
failed=0
for version in "$@"; do
  run_version "${version}" &
  pids+=("$!")
  if (( ${#pids[@]} == 2 )); then
    for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
    pids=()
  fi
done
for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
(( failed == 0 ))
if docker logs "${proxy}" | grep '^DENIED '; then
  printf 'Gitee installation attempted a connection outside the domestic mirror list.\n' >&2
  exit 1
fi
