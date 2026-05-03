#!/usr/bin/env bash
# oh-my-devpod toolchain installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/setup.sh | bash
#   curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/setup.sh | bash
#   curl -fsSL https://gitlab.com/zhangdw156/oh-my-devpod/-/raw/main/install/setup.sh | bash
set -euo pipefail

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
DEVPOD_DATA="${HOME}/.local/share/devpod"
DEVPOD_ZSH="${DEVPOD_DATA}/zsh"
DEVPOD_OWNER="zhangdw156"
DEVPOD_REPO="oh-my-devpod"
DEVPOD_BRANCH="main"

info()  { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Linux" ]]; then
  error "This installer supports Linux only."
fi

for cmd in bash curl git; do
  command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
done

# ── Mirror infrastructure ────────────────────────────────────────────
info "Probing git hosts..."
MIRROR_HOSTS=()
for _host in github.com gitee.com gitlab.com; do
  if curl -fsSL --connect-timeout 3 --max-time 5 -o /dev/null \
       "https://${_host}/${DEVPOD_OWNER}/${DEVPOD_REPO}" 2>/dev/null; then
    MIRROR_HOSTS+=("${_host}")
    printf '  \033[32m✓\033[0m %s\n' "${_host}"
  else
    printf '  \033[31m✗\033[0m %s\n' "${_host}"
  fi
done

if [[ ${#MIRROR_HOSTS[@]} -eq 0 ]]; then
  warn "No reachable git host found; some components may fail to install"
fi
info "Mirrors: ${MIRROR_HOSTS[*]:-none}"

_raw_url() {
  local host="$1" path="$2"
  case "${host}" in
    github.com) echo "https://raw.githubusercontent.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/${DEVPOD_BRANCH}/${path}" ;;
    gitee.com)  echo "https://gitee.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/raw/${DEVPOD_BRANCH}/${path}" ;;
    gitlab.com) echo "https://gitlab.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/-/raw/${DEVPOD_BRANCH}/${path}" ;;
  esac
}

_git_url() {
  echo "https://$1/${DEVPOD_OWNER}/${DEVPOD_REPO}.git"
}

_archive_url() {
  local host="$1"
  case "${host}" in
    github.com) echo "https://github.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/archive/refs/heads/${DEVPOD_BRANCH}.tar.gz" ;;
    gitee.com)  echo "https://gitee.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/repository/archive/${DEVPOD_BRANCH}.tar.gz" ;;
    gitlab.com) echo "https://gitlab.com/${DEVPOD_OWNER}/${DEVPOD_REPO}/-/archive/${DEVPOD_BRANCH}/${DEVPOD_REPO}-${DEVPOD_BRANCH}.tar.gz" ;;
  esac
}

_host_reachable() {
  local h
  for h in "${MIRROR_HOSTS[@]:-}"; do
    [[ "${h}" == "$1" ]] && return 0
  done
  return 1
}

download_file() {
  local repo_path="$1" dest="$2" host
  for host in "${MIRROR_HOSTS[@]:-}"; do
    if curl -fsSL --connect-timeout 10 --max-time 60 \
         "$(_raw_url "${host}" "${repo_path}")" -o "${dest}" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

download_vendor_tree() {
  local dest="$1" host _tmp

  # Strategy 1: sparse checkout (~4MB download)
  for host in "${MIRROR_HOSTS[@]:-}"; do
    _tmp="$(mktemp -d)"
    if git clone --depth 1 --filter=blob:none --sparse --no-checkout --quiet \
         "$(_git_url "${host}")" "${_tmp}/repo" 2>/dev/null \
       && git -C "${_tmp}/repo" sparse-checkout set vendor/zsh vendor/nvim config/.p10k.zsh config/nvim 2>/dev/null \
       && git -C "${_tmp}/repo" checkout --quiet 2>/dev/null; then
      cp -R "${_tmp}/repo/vendor/zsh" "${dest}/vendor_zsh"
      [[ ! -d "${_tmp}/repo/vendor/nvim" ]] || cp -R "${_tmp}/repo/vendor/nvim" "${dest}/vendor_nvim"
      [[ ! -f "${_tmp}/repo/config/.p10k.zsh" ]] || cp "${_tmp}/repo/config/.p10k.zsh" "${dest}/p10k.zsh"
      [[ ! -d "${_tmp}/repo/config/nvim" ]] || cp -R "${_tmp}/repo/config/nvim" "${dest}/config_nvim"
      rm -rf "${_tmp}"
      info "Downloaded assets via sparse checkout from ${host}"
      return 0
    fi
    rm -rf "${_tmp}"
  done

  # Strategy 2: archive selective extract (streams ~73MB, writes ~15MB)
  for host in "${MIRROR_HOSTS[@]:-}"; do
    _tmp="$(mktemp -d)"
    if curl -fsSL --connect-timeout 10 --max-time 300 "$(_archive_url "${host}")" 2>/dev/null \
       | tar xz --strip-components 1 --wildcards -C "${_tmp}" \
           '*/vendor/zsh/*' '*/vendor/nvim/*' '*/config/.p10k.zsh' '*/config/nvim/*' 2>/dev/null; then
      if [[ -d "${_tmp}/vendor/zsh" ]]; then
        cp -R "${_tmp}/vendor/zsh" "${dest}/vendor_zsh"
        [[ ! -d "${_tmp}/vendor/nvim" ]] || cp -R "${_tmp}/vendor/nvim" "${dest}/vendor_nvim"
        [[ ! -f "${_tmp}/config/.p10k.zsh" ]] || cp "${_tmp}/config/.p10k.zsh" "${dest}/p10k.zsh"
        [[ ! -d "${_tmp}/config/nvim" ]] || cp -R "${_tmp}/config/nvim" "${dest}/config_nvim"
        rm -rf "${_tmp}"
        info "Downloaded assets via archive from ${host}"
        return 0
      fi
    fi
    rm -rf "${_tmp}"
  done

  return 1
}

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
  if _host_reachable "github.com"; then
    BUN_INSTALL="${HOME}/.bun" curl -fsSL https://bun.sh/install | bash || true
  fi
  if ! command -v bun >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    info "Installing bun via npm..."
    npm install -g bun || warn "Bun installation failed; skipping"
  fi
fi

# ── Python tools ──────────────────────────────────────────────────────
info "Installing harlequin..."
uv tool install --force "harlequin==2.5.2" || warn "Harlequin installation failed; skipping"

# ── Vendored assets (zsh plugins + p10k) ─────────────────────────────
info "Downloading vendored assets from mirrors..."
mkdir -p "${DEVPOD_ZSH}"

_asset_tmp="$(mktemp -d)"
zsh_plugin_ok=true

if download_vendor_tree "${_asset_tmp}"; then
  for _dir in ohmyzsh powerlevel10k zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting; do
    if [[ -d "${_asset_tmp}/vendor_zsh/${_dir}" ]]; then
      rm -rf "${DEVPOD_ZSH:?}/${_dir}"
      cp -R "${_asset_tmp}/vendor_zsh/${_dir}" "${DEVPOD_ZSH}/${_dir}"
    else
      warn "Plugin ${_dir} not found in downloaded assets"
      zsh_plugin_ok=false
    fi
  done

  if [[ -f "${_asset_tmp}/p10k.zsh" ]]; then
    cp "${_asset_tmp}/p10k.zsh" "${HOME}/.p10k.zsh"
  fi

  # LazyVim starter + overlay
  if [[ -d "${_asset_tmp}/vendor_nvim/lazyvim-starter" ]]; then
    info "Setting up LazyVim..."
    _nvim_config="${HOME}/.config/nvim"
    if [[ -d "${_nvim_config}" ]]; then
      mv "${_nvim_config}" "${_nvim_config}.bak.$(date +%s)"
      warn "Existing nvim config backed up"
    fi
    cp -R "${_asset_tmp}/vendor_nvim/lazyvim-starter" "${_nvim_config}"
    if [[ -d "${_asset_tmp}/config_nvim" ]]; then
      cp -R "${_asset_tmp}/config_nvim/." "${_nvim_config}"
    fi
    rm -rf "${_nvim_config}/.git" "${_nvim_config}/.openpod-source-commit"
  fi
else
  warn "Failed to download vendored assets from any mirror"
  zsh_plugin_ok=false

  info "Trying raw URL for .p10k.zsh..."
  download_file "config/.p10k.zsh" "${HOME}/.p10k.zsh" \
    || warn "Failed to download .p10k.zsh"
fi

rm -rf "${_asset_tmp}"

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
  warn "Some components failed to install. Check network connectivity and retry."
fi

zsh_path="$(command -v zsh 2>/dev/null || true)"
echo ""
if [[ -n "${zsh_path}" ]]; then
  if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
    echo "To set zsh as your default shell, first register it:"
    echo "  echo ${zsh_path} | sudo tee -a /etc/shells"
    echo "  chsh -s ${zsh_path}"
  else
    echo "To set zsh as your default shell:"
    echo "  chsh -s ${zsh_path}"
  fi
  echo ""
  echo "Or start zsh now:"
  echo "  exec ${zsh_path}"
else
  warn "zsh not found in PATH"
fi
