#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

[[ -f "${repo_root}/VERSION" ]] || fail "missing VERSION file"
[[ ! -f "${repo_root}/Dockerfile" ]] || fail "root Dockerfile should not exist"
[[ ! -f "${repo_root}/docker-compose.yml" ]] || fail "root docker-compose.yml should not exist"
[[ ! -f "${repo_root}/docker-compose.yaml" ]] || fail "root docker-compose.yaml should not exist"

version="$(tr -d '\r' < "${repo_root}/VERSION")"
version="${version%%$'\n'*}"
version="${version%"${version##*[![:space:]]}"}"
version="${version#"${version%%[![:space:]]*}"}"
[[ -n "${version}" ]] || fail "VERSION file should not be empty"

make_temp_file() {
  mktemp 2>/dev/null || mktemp -t devpod.compose.XXXXXX
}

check_compose() {
  local flavor="$1"
  local compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"
  local tmp_out

  [[ -f "${compose_file}" ]] || fail "missing compose file: ${compose_file}"

  local ghcr_pattern='image:[[:space:]]*ghcr\.io/zhangdw156/'
  ghcr_pattern+="${flavor}"
  ghcr_pattern+=':\$\{IMAGE_VERSION:-latest\}'
  rg -q "${ghcr_pattern}" "${compose_file}" \
    || fail "compose should use ghcr.io/zhangdw156/${flavor}:\${IMAGE_VERSION:-latest} in ${compose_file}"

  if rg -q -F "image: ghcr.io/zhangdw156/${flavor}:${version}" "${compose_file}"; then
    fail "compose should not hard-code ${version} in ${compose_file}"
  fi
  if rg -q 'image:[[:space:]]*ghcr\.io/zhangdw156/(openpod|claudepod|codexpod|copilotpod|geminipod):[0-9]' "${compose_file}"; then
    fail "compose should not hard-code numeric image tags in ${compose_file}"
  fi

  tmp_out="$(make_temp_file)"
  cleanup_tmp() { [[ -n "${tmp_out:-}" ]] && rm -f "${tmp_out}"; }
  trap cleanup_tmp RETURN

  IMAGE_VERSION=test-version $COMPOSE -f "${compose_file}" config > "${tmp_out}"

  if ! rg -q "^  ${flavor}:" "${tmp_out}"; then
    fail "missing compose service ${flavor} in ${compose_file}"
  fi

  if ! rg -q -F "image: ghcr.io/zhangdw156/${flavor}:test-version" "${tmp_out}"; then
    fail "compose should render IMAGE_VERSION for ${flavor} in ${compose_file}"
  fi

  if rg -q "^\\s+env_file:" "${tmp_out}"; then
    fail "compose should not define env_file entries in ${compose_file}"
  fi
  cleanup_tmp
  trap - RETURN
}

for flavor in openpod claudepod codexpod copilotpod geminipod; do
  check_compose "${flavor}"
done
