#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="${repo_root}/vendor"
runtime_dir="${repo_root}/runtime"
openpod_vendor_dir="${runtime_dir}/openpod/vendor"
openpod_opencode_dir="${openpod_vendor_dir}/opencode"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

curl_retry=(
  curl
  -fsSL
  --retry 5
  --retry-delay 2
  --retry-connrefused
  --connect-timeout 15
)

btop_version="v1.4.6"
antidote_version="v2.0.10"
zellij_version="v0.44.0"
yazi_version="v26.1.22"
neovim_version="v0.12.0"
superpowers_version="v5.0.7"
lazyvim_starter_commit="803bc181d7c0d6d5eeba9274d9be49b287294d99"

ohmyzsh_commit="9e2c1548c3dfeefd055e1c6606f66657093ae928"
powerlevel10k_commit="604f19a9eaa18e76db2e60b8d446d5f879065f90"
autosuggestions_commit="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
history_substring_search_commit="14c8d2e0ffaee98f2df9850b19944f32546fdea5"
syntax_highlighting_commit="1d85c692615a25fe2293bdd44b34c217d5d2bf04"

download() {
  local url="$1"
  local output="$2"

  mkdir -p "$(dirname "${output}")"
  "${curl_retry[@]}" "${url}" -o "${output}"
}

download_release_assets() {
  local name="$1"
  local version="$2"
  shift 2

  local release_dir="${vendor_dir}/releases/${name}/${version}"
  mkdir -p "${release_dir}"
  rm -f "${release_dir}"/*

  while (($# > 0)); do
    local asset_name="$1"
    local url="$2"
    shift 2

    download "${url}" "${release_dir}/${asset_name}"
  done

  (
    cd "${release_dir}"
    sha256sum * > SHA256SUMS
  )
}

download_plugin_snapshot() {
  local owner_repo="$1"
  local commit="$2"
  local target_dir="$3"

  local archive_path="${tmp_dir}/$(basename "${target_dir}").tar.gz"
  download "https://codeload.github.com/${owner_repo}/tar.gz/${commit}" "${archive_path}"

  rm -rf "${target_dir}"
  mkdir -p "${target_dir}"
  tar -xzf "${archive_path}" --strip-components=1 -C "${target_dir}"
  find "${target_dir}" -name '.git' -prune -exec rm -rf {} +
}

rm -rf "${vendor_dir}/opencode"
mkdir -p "${vendor_dir}/releases" "${vendor_dir}/nvim" "${vendor_dir}/zsh"
mkdir -p "${openpod_opencode_dir}/packages" "${openpod_opencode_dir}/skills"

download_release_assets \
  "antidote" \
  "${antidote_version}" \
  "antidote-${antidote_version}.tar.gz" \
  "https://codeload.github.com/mattmc3/antidote/tar.gz/refs/tags/${antidote_version}"

download_release_assets \
  "btop" \
  "${btop_version}" \
  "btop-aarch64-unknown-linux-musl.tbz" \
  "https://github.com/aristocratos/btop/releases/download/${btop_version}/btop-aarch64-unknown-linux-musl.tbz" \
  "btop-x86_64-unknown-linux-musl.tbz" \
  "https://github.com/aristocratos/btop/releases/download/${btop_version}/btop-x86_64-unknown-linux-musl.tbz"

download_release_assets \
  "zellij" \
  "${zellij_version}" \
  "zellij-aarch64-unknown-linux-musl.sha256sum" \
  "https://github.com/zellij-org/zellij/releases/download/${zellij_version}/zellij-aarch64-unknown-linux-musl.sha256sum" \
  "zellij-aarch64-unknown-linux-musl.tar.gz" \
  "https://github.com/zellij-org/zellij/releases/download/${zellij_version}/zellij-aarch64-unknown-linux-musl.tar.gz" \
  "zellij-x86_64-unknown-linux-musl.sha256sum" \
  "https://github.com/zellij-org/zellij/releases/download/${zellij_version}/zellij-x86_64-unknown-linux-musl.sha256sum" \
  "zellij-x86_64-unknown-linux-musl.tar.gz" \
  "https://github.com/zellij-org/zellij/releases/download/${zellij_version}/zellij-x86_64-unknown-linux-musl.tar.gz"

download_release_assets \
  "neovim" \
  "${neovim_version}" \
  "nvim-linux-arm64.tar.gz" \
  "https://github.com/neovim/neovim/releases/download/${neovim_version}/nvim-linux-arm64.tar.gz" \
  "nvim-linux-x86_64.tar.gz" \
  "https://github.com/neovim/neovim/releases/download/${neovim_version}/nvim-linux-x86_64.tar.gz"

download_release_assets \
  "yazi" \
  "${yazi_version}" \
  "yazi-aarch64-unknown-linux-gnu.deb" \
  "https://github.com/sxyazi/yazi/releases/download/${yazi_version}/yazi-aarch64-unknown-linux-gnu.deb" \
  "yazi-x86_64-unknown-linux-gnu.deb" \
  "https://github.com/sxyazi/yazi/releases/download/${yazi_version}/yazi-x86_64-unknown-linux-gnu.deb"

download_plugin_snapshot "ohmyzsh/ohmyzsh" "${ohmyzsh_commit}" "${vendor_dir}/zsh/ohmyzsh"
download_plugin_snapshot "romkatv/powerlevel10k" "${powerlevel10k_commit}" "${vendor_dir}/zsh/powerlevel10k"
download_plugin_snapshot "zsh-users/zsh-autosuggestions" "${autosuggestions_commit}" "${vendor_dir}/zsh/zsh-autosuggestions"
download_plugin_snapshot "zsh-users/zsh-history-substring-search" "${history_substring_search_commit}" "${vendor_dir}/zsh/zsh-history-substring-search"
download_plugin_snapshot "zsh-users/zsh-syntax-highlighting" "${syntax_highlighting_commit}" "${vendor_dir}/zsh/zsh-syntax-highlighting"
download_plugin_snapshot "obra/superpowers" "refs/tags/${superpowers_version}" "${openpod_opencode_dir}/packages/superpowers"
download_plugin_snapshot "LazyVim/starter" "${lazyvim_starter_commit}" "${vendor_dir}/nvim/lazyvim-starter"
printf '%s\n' "${lazyvim_starter_commit}" > "${vendor_dir}/nvim/lazyvim-starter/.openpod-source-commit"

for flavor in claudepod codexpod; do
  if [[ -d "${runtime_dir}/${flavor}/skills/superpowers" ]]; then
    rm -rf "${runtime_dir}/${flavor}/skills/superpowers"
  fi
  mkdir -p "${runtime_dir}/${flavor}/skills"
  cp -R "${openpod_opencode_dir}/packages/superpowers/skills" "${runtime_dir}/${flavor}/skills/superpowers"
done

echo "Vendored assets updated under ${vendor_dir} and ${openpod_vendor_dir}"
