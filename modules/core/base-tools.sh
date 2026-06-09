#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

packages=(
  gcc antidote atuin bat btop fd fzf jq make neovim node pigz
  ripgrep sqlite unzip uv vim witr yazi zellij zsh
)
commands=(nvim uv node rg fzf yazi zellij zsh)

brew_cmd() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    printf '%s\n' /home/linuxbrew/.linuxbrew/bin/brew
  else
    return 1
  fi
}

status() {
  local cmd
  for cmd in "${commands[@]}"; do
    command -v "${cmd}" >/dev/null 2>&1 || return 1
  done
}

install_or_update() {
  local action="$1" brew
  shift
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} baseline packages: ${packages[*]}"
    return 0
  fi
  brew="$(brew_cmd)" || { omd_module_info error "Homebrew is required before base tools"; return 1; }
  "${brew}" install "${packages[@]}"
}

case "${1:-}" in
  status) status ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; omd_module_required_uninstall base-tools ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
