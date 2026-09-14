#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
uv_bin="$(command -v uv || true)"
if [[ -z "${uv_bin}" ]]; then
  printf 'SKIP: real uv config discovery test (uv unavailable)\n'
  exit 0
fi
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
export HOME="${tmp_dir}/home"
export XDG_CONFIG_HOME="${HOME}/.config"
export UV_CACHE_DIR="${tmp_dir}/cache"
export OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1
source "${repo_root}/install/bootstrap.sh"
omd_persist_source gitee "${XDG_CONFIG_HOME}/oh-my-devpod"
# Simulate the inherited override from an older login shell.
export UV_CONFIG_FILE="${XDG_CONFIG_HOME}/oh-my-devpod/uv.toml"
source "${XDG_CONFIG_HOME}/oh-my-devpod/env"
mkdir -p "${XDG_CONFIG_HOME}/uv" "${tmp_dir}/project/wheels"
# The native user mirror must merge below project find-links.
cat > "${XDG_CONFIG_HOME}/uv/uv.toml" <<'UV'
[[index]]
url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"
default = true
UV
cat > "${tmp_dir}/project/pyproject.toml" <<'PROJECT'
[project]
name = "omd-config-discovery"
version = "0.0.0"
requires-python = ">=3.10"
dependencies = ["omd-test-wheel==1.0+local"]
[tool.uv]
find-links = ["wheels"]
PROJECT
python3 - "${tmp_dir}/project/wheels" <<'PY'
from pathlib import Path
import sys
import zipfile
wheel = Path(sys.argv[1]) / "omd_test_wheel-1.0+local-py3-none-any.whl"
with zipfile.ZipFile(wheel, "w") as output:
    output.writestr("omd_test_wheel-1.0+local.dist-info/METADATA", "Metadata-Version: 2.1\nName: omd-test-wheel\nVersion: 1.0+local\n")
    output.writestr("omd_test_wheel-1.0+local.dist-info/WHEEL", "Wheel-Version: 1.0\nRoot-Is-Purelib: true\nTag: py3-none-any\n")
PY
(
  cd "${tmp_dir}/project"
  "${uv_bin}" lock --offline --no-index --no-python-downloads --python "$(command -v python3)"
)
grep -Fq 'omd-test-wheel' "${tmp_dir}/project/uv.lock"
printf 'uv project configuration discovery passed\n'
