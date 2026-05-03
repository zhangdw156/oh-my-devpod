#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../versions.env
source "${repo_root}/versions.env"

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

btop_version="${BTOP_VERSION}"
antidote_version="${ANTIDOTE_VERSION}"
zellij_version="${ZELLIJ_VERSION}"
yazi_version="${YAZI_VERSION}"
neovim_version="${NEOVIM_VERSION}"
atuin_version="${ATUIN_VERSION}"
superpowers_version="${SUPERPOWERS_VERSION}"
lazyvim_starter_commit="${LAZYVIM_STARTER_COMMIT}"

ohmyzsh_commit="${OHMYZSH_COMMIT}"
powerlevel10k_commit="${POWERLEVEL10K_COMMIT}"
autosuggestions_commit="${AUTOSUGGESTIONS_COMMIT}"
history_substring_search_commit="${HISTORY_SUBSTRING_SEARCH_COMMIT}"
syntax_highlighting_commit="${SYNTAX_HIGHLIGHTING_COMMIT}"

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

download_release_assets \
  "atuin" \
  "${atuin_version}" \
  "atuin-aarch64-unknown-linux-musl.tar.gz" \
  "https://github.com/atuinsh/atuin/releases/download/${atuin_version}/atuin-aarch64-unknown-linux-musl.tar.gz" \
  "atuin-x86_64-unknown-linux-musl.tar.gz" \
  "https://github.com/atuinsh/atuin/releases/download/${atuin_version}/atuin-x86_64-unknown-linux-musl.tar.gz"

download_plugin_snapshot "ohmyzsh/ohmyzsh" "${ohmyzsh_commit}" "${vendor_dir}/zsh/ohmyzsh"
download_plugin_snapshot "romkatv/powerlevel10k" "${powerlevel10k_commit}" "${vendor_dir}/zsh/powerlevel10k"
download_plugin_snapshot "zsh-users/zsh-autosuggestions" "${autosuggestions_commit}" "${vendor_dir}/zsh/zsh-autosuggestions"
download_plugin_snapshot "zsh-users/zsh-history-substring-search" "${history_substring_search_commit}" "${vendor_dir}/zsh/zsh-history-substring-search"
download_plugin_snapshot "zsh-users/zsh-syntax-highlighting" "${syntax_highlighting_commit}" "${vendor_dir}/zsh/zsh-syntax-highlighting"
download_plugin_snapshot "obra/superpowers" "refs/tags/${superpowers_version}" "${openpod_opencode_dir}/packages/superpowers"
download_plugin_snapshot "LazyVim/starter" "${lazyvim_starter_commit}" "${vendor_dir}/nvim/lazyvim-starter"
printf '%s\n' "${lazyvim_starter_commit}" > "${vendor_dir}/nvim/lazyvim-starter/.openpod-source-commit"

for flavor in claudepod codexpod copilotpod geminipod; do
  if [[ -d "${runtime_dir}/${flavor}/skills/superpowers" ]]; then
    rm -rf "${runtime_dir}/${flavor}/skills/superpowers"
  fi
  mkdir -p "${runtime_dir}/${flavor}/skills"
  cp -R "${openpod_opencode_dir}/packages/superpowers/skills" "${runtime_dir}/${flavor}/skills/superpowers"
done

echo "Vendored assets updated under ${vendor_dir} and ${openpod_vendor_dir}"
