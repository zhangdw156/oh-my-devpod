# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH=/opt/vendor/zsh/ohmyzsh
export ZSH_DISABLE_COMPFIX=true
export DISABLE_AUTO_UPDATE=true
ZSH_THEME=""
plugins=(git extract)

source "${ZSH}/oh-my-zsh.sh"
[[ -f /opt/vendor/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/vendor/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /opt/vendor/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
  source /opt/vendor/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
[[ -f /opt/vendor/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/vendor/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /opt/vendor/zsh/powerlevel10k/powerlevel10k.zsh-theme ]] && \
  source /opt/vendor/zsh/powerlevel10k/powerlevel10k.zsh-theme

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
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
