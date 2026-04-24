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
  antidote bat btop fd fzf jq make neovim node
  ripgrep sqlite unzip uv vim yazi zellij zsh
)
info "Installing packages: ${packages[*]}"
brew install "${packages[@]}"

# ── Bun ───────────────────────────────────────────────────────────────
if ! command -v bun >/dev/null 2>&1; then
  info "Installing bun..."
  BUN_INSTALL="${HOME}/.bun" curl -fsSL https://bun.sh/install | bash
fi

# ── Zsh plugins ───────────────────────────────────────────────────────
info "Setting up zsh plugins..."
mkdir -p "${DEVPOD_ZSH}"

clone_or_pull() {
  local repo="$1" dest="$2"
  if [[ -d "${dest}/.git" ]]; then
    git -C "${dest}" pull --quiet 2>/dev/null || true
  else
    rm -rf "${dest}"
    git clone --depth 1 --quiet "https://github.com/${repo}.git" "${dest}"
  fi
}

clone_or_pull "ohmyzsh/ohmyzsh"                        "${DEVPOD_ZSH}/ohmyzsh"
clone_or_pull "romkatv/powerlevel10k"                   "${DEVPOD_ZSH}/powerlevel10k"
clone_or_pull "zsh-users/zsh-autosuggestions"           "${DEVPOD_ZSH}/zsh-autosuggestions"
clone_or_pull "zsh-users/zsh-history-substring-search"  "${DEVPOD_ZSH}/zsh-history-substring-search"
clone_or_pull "zsh-users/zsh-syntax-highlighting"       "${DEVPOD_ZSH}/zsh-syntax-highlighting"

# ── .p10k.zsh ─────────────────────────────────────────────────────────
info "Downloading powerlevel10k preset..."
curl -fsSL "${DEVPOD_RAW}/config/.p10k.zsh" -o "${HOME}/.p10k.zsh"

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
for tool in bat btop bun fd fzf gcc git jq make nvim node npm rg sqlite3 uv vim yazi zellij zsh; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m %s\n' "$tool"
  else
    printf '  \033[31m✗\033[0m %s\n' "$tool"
  fi
done

echo ""
echo "Zsh plugins:"
for p in ohmyzsh powerlevel10k zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting; do
  printf '  \033[32m✓\033[0m %s\n' "$p"
done

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
