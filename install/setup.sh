#!/usr/bin/env bash
# oh-my-devpod toolchain installer
# Usage: curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/setup.sh | bash
set -euo pipefail

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
DEVPOD_DATA="${HOME}/.local/share/devpod"
DEVPOD_ZSH="${DEVPOD_DATA}/zsh"
DEVPOD_RAW="https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main"

info()  { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Linux" ]]; then
  error "This installer supports Linux only."
fi

for cmd in bash curl git; do
  command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
done

# ── Homebrew ──────────────────────────────────────────────────────────
if [[ -x "${HOMEBREW_PREFIX}/bin/brew" ]]; then
  info "Homebrew already installed"
else
  info "Installing Homebrew..."
  if ! mkdir -p "${HOMEBREW_PREFIX}" 2>/dev/null; then
    if command -v sudo >/dev/null 2>&1; then
      sudo mkdir -p "${HOMEBREW_PREFIX}" && sudo chown -R "$(id -u):$(id -g)" "${HOMEBREW_PREFIX}"
    else
      error "Cannot create ${HOMEBREW_PREFIX}. Run: sudo mkdir -p ${HOMEBREW_PREFIX} && sudo chown \$(id -u):\$(id -g) ${HOMEBREW_PREFIX}"
    fi
  fi
  curl -fsSL https://github.com/Homebrew/brew/tarball/master \
    | tar xz --strip-components 1 -C "${HOMEBREW_PREFIX}"
fi

eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

# ── Compiler toolchain ────────────────────────────────────────────────
info "Installing compiler toolchain..."
brew install gcc || true
gcc_bin="$(ls "${HOMEBREW_PREFIX}/bin"/gcc-[0-9]* 2>/dev/null | sort -V | tail -1)"
if [[ -n "${gcc_bin}" ]]; then
  ln -sfn "${gcc_bin}" "${HOMEBREW_PREFIX}/bin/gcc"
  ln -sfn "${gcc_bin}" "${HOMEBREW_PREFIX}/bin/cc"
fi
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

# ── Core tools ────────────────────────────────────────────────────────
packages=(
  antidote atuin bat btop fd fzf jq make neovim node pigz
  ripgrep sqlite unzip uv vim yazi zellij zsh
)
info "Installing packages: ${packages[*]}"
brew install "${packages[@]}"

# ── Bun ───────────────────────────────────────────────────────────────
if ! command -v bun >/dev/null 2>&1; then
  info "Installing bun..."
  BUN_INSTALL="${HOME}/.bun" curl -fsSL https://bun.sh/install | bash || warn "Bun installation failed (network issue?); skipping"
fi

# ── Python tools ──────────────────────────────────────────────────────
info "Installing harlequin..."
uv tool install --force "harlequin==2.5.2" || warn "Harlequin installation failed; skipping"

# ── Zsh plugins ───────────────────────────────────────────────────────
info "Setting up zsh plugins..."
mkdir -p "${DEVPOD_ZSH}"

clone_or_pull() {
  local repo="$1" dest="$2"
  if [[ -d "${dest}/.git" ]]; then
    git -C "${dest}" pull --quiet 2>/dev/null || true
  else
    rm -rf "${dest}"
    git clone --depth 1 --quiet "https://github.com/${repo}.git" "${dest}" || return 1
  fi
}

zsh_plugin_ok=true
for _plugin in \
  "ohmyzsh/ohmyzsh:ohmyzsh" \
  "romkatv/powerlevel10k:powerlevel10k" \
  "zsh-users/zsh-autosuggestions:zsh-autosuggestions" \
  "zsh-users/zsh-history-substring-search:zsh-history-substring-search" \
  "zsh-users/zsh-syntax-highlighting:zsh-syntax-highlighting"; do
  _repo="${_plugin%%:*}"
  _dir="${_plugin##*:}"
  if ! clone_or_pull "${_repo}" "${DEVPOD_ZSH}/${_dir}"; then
    warn "Failed to clone ${_repo} (network issue?); skipping"
    zsh_plugin_ok=false
  fi
done

# ── .p10k.zsh ─────────────────────────────────────────────────────────
info "Downloading powerlevel10k preset..."
if ! curl -fsSL --connect-timeout 15 "${DEVPOD_RAW}/config/.p10k.zsh" -o "${HOME}/.p10k.zsh"; then
  warn "Failed to download .p10k.zsh; skipping"
fi

# ── .zshrc ────────────────────────────────────────────────────────────
info "Writing ~/.zshrc..."
if [[ -f "${HOME}/.zshrc" ]]; then
  cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak.$(date +%s)"
  warn "Existing .zshrc backed up"
fi

cat > "${HOME}/.zshrc" <<'ZSHRC_EOF'
# oh-my-devpod managed zsh config
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

export ZSH="$HOME/.local/share/devpod/zsh/ohmyzsh"
export ZSH_DISABLE_COMPFIX=true
export DISABLE_AUTO_UPDATE=true
ZSH_THEME=""
plugins=(git extract)

source "${ZSH}/oh-my-zsh.sh"
source "$HOME/.local/share/devpod/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$HOME/.local/share/devpod/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "$HOME/.local/share/devpod/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$HOME/.local/share/devpod/zsh/powerlevel10k/powerlevel10k.zsh-theme"

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh 2>/dev/null) || true
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

export EDITOR=nvim
export VISUAL=nvim
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias cc=clear
alias zj=zellij

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  cwd="$(command cat -- "$tmp" 2>/dev/null)"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
ZSHRC_EOF

# ── Summary ───────────────────────────────────────────────────────────
echo ""
info "Installation complete!"
echo ""
echo "Installed tools:"
for tool in atuin bat btop bun fd fzf gcc git harlequin jq make nvim node npm rg sqlite3 uv vim yazi zellij zsh; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m %s\n' "$tool"
  else
    printf '  \033[31m✗\033[0m %s\n' "$tool"
  fi
done

echo ""
echo "Zsh plugins:"
for p in ohmyzsh powerlevel10k zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting; do
  if [[ -d "${DEVPOD_ZSH}/${p}" ]]; then
    printf '  \033[32m✓\033[0m %s\n' "$p"
  else
    printf '  \033[31m✗\033[0m %s\n' "$p"
  fi
done

if [[ "${zsh_plugin_ok}" != "true" ]]; then
  echo ""
  warn "Some components failed to download (github.com unreachable)."
  echo "  For offline / restricted-network environments, use bootstrap.sh instead:"
  echo "    1. Copy the repo to this server (scp, rsync, USB, etc.)"
  echo "    2. bash install/bootstrap.sh --flavor <flavor> --user"
  echo "  bootstrap.sh uses vendored assets and does not require github.com access."
fi

zsh_path="$(command -v zsh 2>/dev/null || true)"
echo ""
if [[ -n "${zsh_path}" ]]; then
  echo "To use zsh as your default shell:"
  echo "  chsh -s ${zsh_path}"
  echo ""
  echo "Or start zsh now:"
  echo "  exec ${zsh_path}"
else
  warn "zsh not found in PATH"
fi
