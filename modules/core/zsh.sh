#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

repo_root="$(omd_module_repo_root)"
devpod_data="${HOME}/.local/share/devpod"
devpod_zsh="${devpod_data}/zsh"

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
  command -v zsh >/dev/null 2>&1 && [[ -f "${HOME}/.zshrc" ]] && grep -q 'oh-my-devpod managed zsh config' "${HOME}/.zshrc"
}

write_zshrc() {
  mkdir -p "${devpod_zsh}"
  if [[ -f "${HOME}/.zshrc" && ! -f "${HOME}/.zshrc.oh-my-devpod.bak" ]]; then
    cp "${HOME}/.zshrc" "${HOME}/.zshrc.oh-my-devpod.bak"
  fi
  cat > "${HOME}/.zshrc" <<'ZSHRC'
# oh-my-devpod managed zsh config
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export ZSH="$HOME/.local/share/devpod/zsh/ohmyzsh"
export ZSH_DISABLE_COMPFIX=true
export DISABLE_AUTO_UPDATE=true
ZSH_THEME=""
plugins=(git extract)
[[ -f "${ZSH}/oh-my-zsh.sh" ]] && source "${ZSH}/oh-my-zsh.sh"
[[ -f "$HOME/.local/share/devpod/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOME/.local/share/devpod/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$HOME/.local/share/devpod/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] && source "$HOME/.local/share/devpod/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh"
[[ -f "$HOME/.local/share/devpod/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOME/.local/share/devpod/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$HOME/.local/share/devpod/zsh/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$HOME/.local/share/devpod/zsh/powerlevel10k/powerlevel10k.zsh-theme"
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh 2>/dev/null) || true
fi
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
export EDITOR=nvim
export VISUAL=nvim
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias cc=clear
alias zj=zellij
ZSHRC
}

install_or_update() {
  local action="$1" brew
  shift
  if omd_module_dry_run "$@"; then
    omd_module_info plan "${action} zsh, zsh plugins, p10k config, and managed ~/.zshrc"
    return 0
  fi
  brew="$(brew_cmd)" || { omd_module_info error "Homebrew is required before zsh environment"; return 1; }
  "${brew}" install zsh antidote atuin fzf
  mkdir -p "${devpod_zsh}"
  if [[ -d "${repo_root}/vendor/zsh" ]]; then
    cp -R "${repo_root}/vendor/zsh/." "${devpod_zsh}/"
  fi
  [[ ! -f "${repo_root}/config/.p10k.zsh" ]] || cp "${repo_root}/config/.p10k.zsh" "${HOME}/.p10k.zsh"
  write_zshrc
}

case "${1:-}" in
  status) status ;;
  install) shift; install_or_update install "$@" ;;
  update) shift; install_or_update update "$@" ;;
  uninstall) shift; omd_module_required_uninstall zsh ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac
