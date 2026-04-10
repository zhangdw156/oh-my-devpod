#!/usr/bin/env bash
set -euo pipefail

# ── Non-root user init ───────────────────────────────────────────────
# When the container runs with --user (non-root), config files that
# were installed under /root at build time are not visible because
# /root is mode 700.  A world-readable skeleton copy lives in
# /opt/devpod-skel; this entrypoint copies it into $HOME.

SKEL=/opt/devpod-skel

if [[ "$(id -u)" -ne 0 ]]; then
  # Ensure $HOME is usable
  if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
    export HOME="/home/devpod"
  fi
  mkdir -p "${HOME}"

  # Helper: copy a file/dir from skel to $HOME if source exists and
  # target does not, preserving symlinks.
  _init_copy() {
    local rel="$1"
    if [[ -e "${SKEL}/${rel}" && ! -e "${HOME}/${rel}" ]]; then
      mkdir -p "$(dirname "${HOME}/${rel}")"
      cp -a "${SKEL}/${rel}" "${HOME}/${rel}"
    fi
  }

  # ── Shell config ──
  _init_copy .zshrc
  _init_copy .p10k.zsh

  # ── Git ──
  _init_copy .gitconfig

  # ── Neovim / LazyVim ──
  _init_copy .config/nvim
  _init_copy .local/share/nvim
  _init_copy .local/state/nvim
  _init_copy .cache/nvim

  # ── Flavor-specific (only copied when the dir exists in the skel) ──
  # openpod
  _init_copy .config/opencode

  # claudepod
  _init_copy .claude
  _init_copy .claude.json
  _init_copy .local/share/claude
  _init_copy .local/bin

  # codexpod
  _init_copy .codex

  # Ensure $HOME/.local/bin is on PATH (claudepod puts binaries there)
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi

# If the first argument looks like a shell flag (e.g. -lc '...'),
# prepend /bin/zsh so that "docker run <image> -lc 'cmd'" still works
# the same way it did when ENTRYPOINT was ["/bin/zsh"].
if [[ "${1:-}" == -* ]]; then
  exec /bin/zsh "$@"
fi

exec "$@"
