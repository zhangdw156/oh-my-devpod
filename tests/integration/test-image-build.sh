#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tag_prefix="devpod-test-$$"
built_images=()

fail() { echo "FAIL: $*" >&2; exit 1; }

export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-0}"

cleanup() {
  echo "Cleaning up test images..."
  for img in "${built_images[@]}"; do
    docker rmi -f "${img}" 2>/dev/null || true
  done
}
trap cleanup EXIT

echo "=== Building devpod base image ==="
base_tag="${tag_prefix}-devpod"
docker build -f "${repo_root}/Dockerfile.devpod" -t "${base_tag}" "${repo_root}"
built_images+=("${base_tag}")

echo "=== Verifying shared tools in devpod base ==="
shared_tools=(bat fd fzf jq rg sqlite3 nvim zellij yazi btop uv bun node npm git zsh gcc make)
for tool in "${shared_tools[@]}"; do
  docker run --rm "${base_tag}" -lc "command -v ${tool}" >/dev/null 2>&1 \
    || fail "tool '${tool}' not found in devpod base"
  echo "  ${tool}: ok"
done

flavors=(openpod claudepod codexpod copilotpod geminipod)
flavor_cmds=(opencode claude codex copilot gemini)

for i in "${!flavors[@]}"; do
  flavor="${flavors[$i]}"
  cmd="${flavor_cmds[$i]}"
  echo "=== Building ${flavor} image ==="
  flavor_tag="${tag_prefix}-${flavor}"
  docker build -f "${repo_root}/docker/${flavor}/Dockerfile" \
    --build-arg "DEVPOD_BASE_IMAGE=${base_tag}" \
    -t "${flavor_tag}" "${repo_root}"
  built_images+=("${flavor_tag}")

  echo "=== Verifying ${flavor} harness ==="
  docker run --rm --user "$(id -u):$(id -g)" "${flavor_tag}" -lc "command -v ${cmd}" >/dev/null 2>&1 \
    || fail "harness command '${cmd}' not found in ${flavor}"
  echo "  ${cmd}: ok"
done

echo "=== test-image-build PASSED ==="
