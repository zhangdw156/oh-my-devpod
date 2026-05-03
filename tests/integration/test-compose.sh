#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

export DOCKER_BUILDKIT=1

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

flavors=(openpod claudepod codexpod copilotpod geminipod)
flavor_smoke_cmds=(
  "opencode --version"
  "command -v claude"
  "codex --help | head -1"
  "copilot --version"
  "gemini --version"
)

test_tag="integ-test"

cleanup() {
  echo "Cleaning up test images..."
  for flavor in "${flavors[@]}"; do
    docker rmi "ghcr.io/zhangdw156/${flavor}:${test_tag}" 2>/dev/null || true
  done
  docker rmi "ghcr.io/zhangdw156/devpod:${test_tag}" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Building devpod base image ==="
docker build -f "${repo_root}/Dockerfile.devpod" \
  -t "ghcr.io/zhangdw156/devpod:${test_tag}" "${repo_root}"

for i in "${!flavors[@]}"; do
  flavor="${flavors[$i]}"
  smoke_cmd="${flavor_smoke_cmds[$i]}"
  compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"

  echo "=== Building ${flavor} image ==="
  docker build -f "${repo_root}/docker/${flavor}/Dockerfile" \
    --build-arg "DEVPOD_BASE_IMAGE=ghcr.io/zhangdw156/devpod:${test_tag}" \
    -t "ghcr.io/zhangdw156/${flavor}:${test_tag}" "${repo_root}"

  echo "=== Running ${flavor} smoke test ==="
  IMAGE_VERSION="${test_tag}" $COMPOSE -f "${compose_file}" run --rm \
    --user "$(id -u):$(id -g)" "${flavor}" \
    -lc "${smoke_cmd}" >/dev/null 2>&1 \
    || fail "${flavor}: '${smoke_cmd}' failed"
  echo "  ${flavor}: ok"
done

echo "=== test-compose PASSED ==="
