#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -q 'install-neovim.sh' "${repo_root}/Dockerfile.devpod"
grep -q 'install-lazyvim.sh' "${repo_root}/Dockerfile.devpod"
grep -q 'install-python-dev-tools.sh' "${repo_root}/Dockerfile.devpod"
grep -q 'build/install-lazyvim.sh' "${repo_root}/install/bootstrap.sh"
grep -q 'build/install-python-dev-tools.sh' "${repo_root}/install/bootstrap.sh"
