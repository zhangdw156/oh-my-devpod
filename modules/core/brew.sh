#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

brew_prefix="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"

status() {
  [[ -x "${brew_prefix}/bin/brew" ]] || command -v brew >/dev/null 2>&1
}

install_or_update() {
  local action="$1"
  shift
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} Homebrew prerequisites and Homebrew under ${brew_prefix}"
    return 0
  fi

  sudo apt-get update
  sudo apt-get install -y build-essential procps curl file git ca-certificates
  if [[ ! -x "${brew_prefix}/bin/brew" ]]; then
    sudo mkdir -p "${brew_prefix}"
    sudo chown -R "$(id -u):$(id -g)" "${brew_prefix}"
    curl -fsSL https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C "${brew_prefix}"
  fi
  "${brew_prefix}/bin/brew" update || true
}

case "${1:-}" in
  status) status ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; omd_module_required_uninstall brew ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
