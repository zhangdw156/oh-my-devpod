#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -q 'neovim' "${repo_root}/modules/core/base-tools.sh"
[[ -f "${repo_root}/build/install-lazyvim.sh" ]]
[[ -f "${repo_root}/build/install-python-dev-tools.sh" ]]
