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

cleanup() {
  echo "Cleaning up compose resources..."
  for flavor in "${flavors[@]}"; do
    $COMPOSE -f "${repo_root}/docker/${flavor}/docker-compose.yaml" down --rmi local --remove-orphans 2>/dev/null || true
  done
}
trap cleanup EXIT

for i in "${!flavors[@]}"; do
  flavor="${flavors[$i]}"
  smoke_cmd="${flavor_smoke_cmds[$i]}"
  compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"

  echo "=== Building ${flavor} via compose ==="
  $COMPOSE -f "${compose_file}" build

  echo "=== Running ${flavor} smoke test ==="
  $COMPOSE -f "${compose_file}" run --rm --user "$(id -u):$(id -g)" "${flavor}" \
    -lc "${smoke_cmd}" >/dev/null 2>&1 \
    || fail "${flavor}: '${smoke_cmd}' failed"
  echo "  ${flavor}: ok"
done

echo "=== test-compose PASSED ==="
