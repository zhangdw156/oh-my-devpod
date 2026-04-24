#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tag_prefix="devpod-bootstrap-test-$$"
test_image="${tag_prefix}-ubuntu"
test_container="${tag_prefix}-run"

fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
  echo "Cleaning up bootstrap test resources..."
  docker rm -f "${test_container}" 2>/dev/null || true
  docker rmi -f "${test_image}" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Building minimal test image (bash + curl + tar + git only) ==="
docker build -t "${test_image}" - <<'DOCKERFILE'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends bash curl tar git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash testuser \
    && mkdir -p /home/linuxbrew && chown testuser:testuser /home/linuxbrew
USER testuser
WORKDIR /home/testuser
DOCKERFILE

echo "=== Running bootstrap inside container (no sudo) ==="
docker run --name "${test_container}" \
  -v "${repo_root}:/workspace:ro" \
  "${test_image}" \
  bash -c '
    set -euo pipefail
    cp -R /workspace /tmp/oh-my-devpod
    cd /tmp/oh-my-devpod
    bash install/bootstrap.sh --flavor claudepod --user

    source "$HOME/.local/claudepod/env.sh"

    echo "=== Verifying brew-installed tools ==="
    tools=(bat fd fzf jq rg nvim zellij yazi bun uv node git zsh btop)
    for tool in "${tools[@]}"; do
      command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool not found"; exit 1; }
      echo "  $tool: ok"
    done

    echo "=== Verifying claudepod harness ==="
    command -v claude >/dev/null 2>&1 || { echo "FAIL: claude not found"; exit 1; }
    echo "  claude: ok"

    echo "=== Bootstrap verification complete ==="
  '

echo "=== test-bootstrap PASSED ==="
