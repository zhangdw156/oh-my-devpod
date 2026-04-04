#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "expected file: ${path}"
}

assert_executable() {
  local path="$1"
  [[ -x "${path}" ]] || fail "expected executable: ${path}"
}

asset_root="${tmp_dir}/assets"
release_dir="${asset_root}/neovim/v0.12.0"
bin_dir="${tmp_dir}/bin"
neovim_dir="${tmp_dir}/opt/neovim"
staging_dir="${tmp_dir}/staging/nvim-linux-x86_64"

mkdir -p "${release_dir}" "${bin_dir}" "${neovim_dir}" "${staging_dir}/bin" "${staging_dir}/share/nvim/runtime"
printf '#!/usr/bin/env bash\necho nvim-test\n' > "${staging_dir}/bin/nvim"
chmod +x "${staging_dir}/bin/nvim"
printf 'runtime marker\n' > "${staging_dir}/share/nvim/runtime/help.txt"

archive_name="nvim-linux-x86_64.tar.gz"
tar -czf "${release_dir}/${archive_name}" -C "${tmp_dir}/staging" "nvim-linux-x86_64"
(cd "${release_dir}" && sha256sum "${archive_name}" > SHA256SUMS)

OPENPOD_ASSET_ROOT="${asset_root}" \
OPENPOD_BIN_DIR="${bin_dir}" \
OPENPOD_NEOVIM_DIR="${neovim_dir}" \
TARGETARCH=amd64 \
bash "${repo_root}/build/install-neovim.sh"

assert_executable "${bin_dir}/nvim"
assert_executable "${neovim_dir}/bin/nvim"
assert_file "${neovim_dir}/share/nvim/runtime/help.txt"
