#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${repo_root}/tests/test-bootstrap.sh"
bash "${repo_root}/tests/test-module-contracts.sh"
if command -v cargo >/dev/null 2>&1; then
  (cd "${repo_root}" && cargo test -p omd)
fi

bash "${repo_root}/tests/test-install-neovim.sh"
bash "${repo_root}/tests/test-install-python-dev-tools.sh"
bash "${repo_root}/tests/test-install-lazyvim.sh"
bash "${repo_root}/tests/test-install-setup-homebrew-mirror.sh"
bash "${repo_root}/tests/test-neovim-lazyvim-wiring.sh"
bash "${repo_root}/tests/test-host-installer-layout.sh"
bash "${repo_root}/tests/test-vendor-assets-layout.sh"
bash "${repo_root}/tests/test-omd-release-workflow.sh"
bash "${repo_root}/tests/test-version-docs.sh"
bash "${repo_root}/tests/test-versions-env.sh"
