#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="${1:-${repo_root}/target/release/omd}"
mkdir -p "$(dirname "${binary}")"
output_dir="$(cd "$(dirname "${binary}")" && pwd)"

# Build with the oldest supported glibc so every LTS can use the same archive.
docker run --rm --platform linux/amd64 \
  --mount "type=bind,src=${repo_root},dst=/source,readonly" \
  --mount "type=bind,src=${output_dir},dst=/output" \
  ubuntu:20.04 bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends build-essential ca-certificates curl
    curl -fsSL --retry 3 https://sh.rustup.rs | sh -s -- -y --profile minimal
    cd /source
    "$HOME/.cargo/bin/cargo" build --locked --release -p omd --target-dir /tmp/target
    install -o "$1" -g "$2" -m 0755 /tmp/target/release/omd "/output/$3"
  ' _ "$(id -u)" "$(id -g)" "$(basename "${binary}")"
