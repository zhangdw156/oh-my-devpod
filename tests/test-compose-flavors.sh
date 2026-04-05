#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

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
  mktemp 2>/dev/null || mktemp -t oh-my-openpod.compose.XXXXXX
}

check_compose() {
  local flavor="$1"
  local compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"
  local tmp_out

  [[ -f "${compose_file}" ]] || fail "missing compose file: ${compose_file}"
  rg -q 'image:[[:space:]]*oh-my-devpod:\$\{IMAGE_VERSION:-local\}' "${compose_file}" \
    || fail "compose should use IMAGE_VERSION for devpod in ${compose_file}"
  flavor_pattern='image:[[:space:]]*oh-my-'
  flavor_pattern+="${flavor}"
  flavor_pattern+=':\$\{IMAGE_VERSION:-local\}'
  rg -q "${flavor_pattern}" "${compose_file}" \
    || fail "compose should use IMAGE_VERSION for ${flavor} in ${compose_file}"
  if rg -q -F "image: oh-my-devpod:${version}" "${compose_file}" \
    || rg -q -F "image: oh-my-${flavor}:${version}" "${compose_file}"; then
    fail "compose should not hard-code ${version} in ${compose_file}"
  fi
  if rg -q 'image:[[:space:]]*oh-my-(devpod|openpod|claudepod|codexpod):[0-9]' "${compose_file}"; then
    fail "compose should not hard-code numeric image tags in ${compose_file}"
  fi

  tmp_out="$(make_temp_file)"
  cleanup_tmp() { [[ -n "${tmp_out:-}" ]] && rm -f "${tmp_out}"; }
  trap cleanup_tmp RETURN
  IMAGE_VERSION=test-version docker compose -f "${compose_file}" config > "${tmp_out}"

  for service in devpod "${flavor}"; do
    if ! rg -q "^  ${service}:" "${tmp_out}"; then
      fail "missing compose service ${service} in ${compose_file}"
    fi
  done

  for dockerfile in \
    "dockerfile: Dockerfile.devpod" \
    "dockerfile: docker/${flavor}/Dockerfile"; do
    if ! rg -q "${dockerfile}" "${tmp_out}"; then
      fail "missing compose dockerfile path ${dockerfile} in ${compose_file}"
    fi
  done

  if ! rg -q -F 'image: oh-my-devpod:test-version' "${tmp_out}"; then
    fail "compose should render IMAGE_VERSION for devpod in ${compose_file}"
  fi
  if ! rg -q -F "image: oh-my-${flavor}:test-version" "${tmp_out}"; then
    fail "compose should render IMAGE_VERSION for ${flavor} in ${compose_file}"
  fi

  if rg -q "^\\s+env_file:" "${tmp_out}"; then
    fail "compose should not define env_file entries in ${compose_file}"
  fi
  cleanup_tmp
  trap - RETURN
}

for flavor in openpod claudepod codexpod; do
  check_compose "${flavor}"
done
