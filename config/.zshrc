# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH=/opt/vendor/zsh/ohmyzsh
ZSH_DISABLE_COMPFIX=false
# Old compinit -u dumps can pass compinit's file-count check after a package update.
: ${ZSH_COMPDUMP:="${ZDOTDIR:-$HOME}/.zcompdump-${HOST%%.*}-$ZSH_VERSION"}
[[ $ZSH_COMPDUMP == *.omd-audited ]] || ZSH_COMPDUMP+=.omd-audited
export DISABLE_AUTO_UPDATE=true
ZSH_THEME=""
plugins=(git extract z)

source "${ZSH}/oh-my-zsh.sh"

# Micromamba registers completions with the audited compinit loaded by Oh My Zsh.
omd_mamba_hook=""
if command -v mamba >/dev/null 2>&1; then
  omd_mamba_hook="$(mamba shell hook --shell zsh 2>/dev/null)" || omd_mamba_hook=""
fi
if [[ -z "${omd_mamba_hook}" ]] && command -v micromamba >/dev/null 2>&1; then
  omd_mamba_hook="$(micromamba shell hook --shell zsh 2>/dev/null)" || omd_mamba_hook=""
fi
[[ -z "${omd_mamba_hook}" ]] || eval "${omd_mamba_hook}"
unset omd_mamba_hook

[[ -f /opt/vendor/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/vendor/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /opt/vendor/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
  source /opt/vendor/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
[[ -f /opt/vendor/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/vendor/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
if [[ "${OHMYDEVPOD_MIRROR_PROFILE:-}" == cn ]]; then
  typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=true
fi
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

if [[ -z "${EDITOR:-}" && -z "${VISUAL:-}" ]] && command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim VISUAL=nvim
fi
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias cc=clear
if command -v zellij >/dev/null 2>&1; then
  alias zj=zellij
fi

if command -v yazi >/dev/null 2>&1; then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1
    command yazi "$@" --cwd-file="$tmp"
    cwd="$(command cat -- "$tmp" 2>/dev/null)"
    [[ -d "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi
