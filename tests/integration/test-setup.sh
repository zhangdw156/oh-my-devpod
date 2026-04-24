#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tag_prefix="devpod-setup-test-$$"
test_image="${tag_prefix}-ubuntu"
test_container="${tag_prefix}-run"

fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
  echo "Cleaning up setup test resources..."
  docker rm -f "${test_container}" 2>/dev/null || true
  docker rmi -f "${test_image}" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Building minimal test image ==="
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-0}" docker build -t "${test_image}" - <<'DOCKERFILE'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends bash curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash testuser \
    && mkdir -p /home/linuxbrew && chown testuser:testuser /home/linuxbrew
USER testuser
WORKDIR /home/testuser
DOCKERFILE

echo "=== Running setup.sh inside container ==="
docker run --name "${test_container}" \
  -v "${repo_root}:/workspace:ro" \
  "${test_image}" \
  bash -c '
    set -euo pipefail
    bash /workspace/install/setup.sh

    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

    echo "=== Verifying tools ==="
    tools=(bat btop bun fd fzf gcc git jq make nvim node npm rg sqlite3 uv vim yazi zellij zsh)
    for tool in "${tools[@]}"; do
      command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool not found"; exit 1; }
      echo "  $tool: ok"
    done

    echo "=== Verifying zsh plugins ==="
    for p in ohmyzsh powerlevel10k zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting; do
      [[ -d "$HOME/.local/share/devpod/zsh/$p" ]] || { echo "FAIL: plugin $p not found"; exit 1; }
      echo "  $p: ok"
    done

    echo "=== Verifying zsh config ==="
    [[ -f "$HOME/.zshrc" ]] || { echo "FAIL: .zshrc not found"; exit 1; }
    echo "  .zshrc: ok"
    [[ -f "$HOME/.p10k.zsh" ]] || { echo "FAIL: .p10k.zsh not found"; exit 1; }
    echo "  .p10k.zsh: ok"
    grep -q "oh-my-devpod" "$HOME/.zshrc" || { echo "FAIL: .zshrc not managed by devpod"; exit 1; }
    echo "  .zshrc content: ok"

    echo "=== Verifying zsh can source config ==="
    zsh -c "source ~/.zshrc && echo zsh-load: ok" 2>/dev/null || { echo "FAIL: zsh cannot source .zshrc"; exit 1; }

    echo "=== Setup verification complete ==="
  '

echo "=== test-setup PASSED ==="
