#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ ! -f "${repo_root}/Dockerfile" ]] || fail "root Dockerfile should not exist"
[[ ! -f "${repo_root}/docker-compose.yml" ]] || fail "root docker-compose.yml should not exist"

check_compose() {
  local flavor="$1"
  local compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"
  local tmp_out

  [[ -f "${compose_file}" ]] || fail "missing compose file: ${compose_file}"

  tmp_out="$(mktemp)"
  docker compose -f "${compose_file}" config > "${tmp_out}"

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

  if rg -q "^\\s+env_file:" "${tmp_out}"; then
    fail "compose should not define env_file entries in ${compose_file}"
  fi

  rm -f "${tmp_out}"
}

for flavor in openpod claudepod codexpod; do
  check_compose "${flavor}"
done
