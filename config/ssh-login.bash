# Sourced at the end of the account's Bash login profile.
if [[ $- == *i* && -t 0 && -n ${SSH_TTY:-} && -z ${BASH_EXECUTION_STRING+x} &&
      -z ${SSH_ORIGINAL_COMMAND+x} && -z ${OHMYDEVPOD_SSH_ZSH:-} &&
      ${ZDOTDIR:-$HOME} == "$HOME" && -O "$HOME/.linuxbrew" && ! -L "$HOME/.linuxbrew" &&
      -x "$HOME/.linuxbrew/bin/zsh" && -O "$HOME/.linuxbrew/bin/zsh" ]] &&
   shopt -q login_shell &&
   grep -Fqx -m1 '# oh-my-devpod managed zsh config' "$HOME/.zshrc" 2>/dev/null; then
  OHMYDEVPOD_SSH_ZSH=1 exec "$HOME/.linuxbrew/bin/zsh" -l
fi
