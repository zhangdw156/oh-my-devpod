#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="user"
flavor="openpod"
prefix=""
prefix_explicit=0

usage() {
  cat <<'EOF'
Usage: bash install/bootstrap.sh [--flavor openpod|claudepod|codexpod|copilotpod|geminipod] [--user] [--system] [--prefix PATH]

Bootstrap a pod-like environment on a Linux host or inside an existing container.

Options:
  --flavor NAME    Select the harness flavor: openpod, claudepod, codexpod, copilotpod, or geminipod
  --user           Install into a user-owned prefix (default)
  --system         Install into /opt/<flavor> with binaries under /usr/local/bin
  --prefix PATH    Override the installation prefix
  -h, --help       Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="$2"
      shift 2
      ;;
    --user)
      mode="user"
      shift
      ;;
    --system)
      mode="system"
      shift
      ;;
    --prefix)
      prefix="$2"
      prefix_explicit=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${flavor}" in
  openpod)
    flavor_name="openpod"
    default_config_home_user="${HOME}/.config/opencode"
    default_config_home_system="/root/.config/opencode"
    ;;
  claudepod)
    flavor_name="claudepod"
    default_config_home_user="${HOME}/.claude"
    default_config_home_system="/root/.claude"
    ;;
  codexpod)
    flavor_name="codexpod"
    default_config_home_user="${HOME}/.codex"
    default_config_home_system="/root/.codex"
    ;;
  copilotpod)
    flavor_name="copilotpod"
    default_config_home_user="${HOME}/.copilot"
    default_config_home_system="/root/.copilot"
    ;;
  geminipod)
    flavor_name="geminipod"
    default_config_home_user="${HOME}/.gemini"
    default_config_home_system="/root/.gemini"
    ;;
  *)
    echo "Unsupported flavor: ${flavor}" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ "${prefix_explicit}" != "1" ]]; then
  if [[ "$mode" == "system" ]]; then
    prefix="${OPENPOD_PREFIX:-/opt/${flavor_name}}"
  else
    prefix="${OPENPOD_PREFIX:-${HOME}/.local/${flavor_name}}"
  fi
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "bootstrap mode currently supports Linux only" >&2
  exit 1
fi

for cmd in bash curl git tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

bin_dir="${OPENPOD_BIN_DIR:-}"
config_home="${OPENPOD_CONFIG_HOME:-}"
data_home="${OPENPOD_DATA_HOME:-}"
state_home="${OPENPOD_STATE_HOME:-}"
cache_home="${OPENPOD_CACHE_HOME:-}"

if [[ -z "${bin_dir}" ]]; then
  if [[ "$mode" == "system" ]]; then
    bin_dir="/usr/local/bin"
  else
    bin_dir="${HOME}/.local/bin"
  fi
fi

if [[ -z "${config_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    config_home="${default_config_home_system}"
  else
    config_home="${default_config_home_user}"
  fi
fi

if [[ -z "${data_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    data_home="/root/.local/share/${flavor_name}"
  else
    data_home="${HOME}/.local/share/${flavor_name}"
  fi
fi

if [[ -z "${state_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    state_home="/root/.local/state/${flavor_name}"
  else
    state_home="${HOME}/.local/state/${flavor_name}"
  fi
fi

if [[ -z "${cache_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    cache_home="/root/.cache/${flavor_name}"
  else
    cache_home="${HOME}/.cache/${flavor_name}"
  fi
fi

vendor_home="${prefix}/vendor"
runtime_home="${prefix}/runtime/${flavor_name}"
runtime_vendor_home="${runtime_home}/vendor"
shell_dir="${prefix}/shell"
xdg_config_home="${HOME}/.config"
xdg_data_home="${HOME}/.local/share"
xdg_state_home="${HOME}/.local/state"
xdg_cache_home="${HOME}/.cache"

if [[ "$mode" == "system" ]]; then
  xdg_config_home="/root/.config"
  xdg_data_home="/root/.local/share"
  xdg_state_home="/root/.local/state"
  xdg_cache_home="/root/.cache"
fi

mkdir -p "${prefix}" "${bin_dir}" "${config_home}" "${data_home}" "${state_home}" "${cache_home}" "${shell_dir}"

# ── Homebrew (Linuxbrew) ──────────────────────────────────────────────
homebrew_prefix="/home/linuxbrew/.linuxbrew"
if [[ ! -x "${homebrew_prefix}/bin/brew" ]]; then
  echo "Installing Homebrew to ${homebrew_prefix}..."
  if ! mkdir -p "${homebrew_prefix}" 2>/dev/null; then
    if command -v sudo >/dev/null 2>&1; then
      sudo mkdir -p "${homebrew_prefix}" && sudo chown -R "$(id -u):$(id -g)" "${homebrew_prefix}"
    else
      echo "Cannot create ${homebrew_prefix}. Please create it manually and grant write access." >&2
      exit 1
    fi
  fi
  curl -fsSL https://github.com/Homebrew/brew/tarball/master \
    | tar xz --strip-components 1 -C "${homebrew_prefix}"
fi

eval "$("${homebrew_prefix}/bin/brew" shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

echo "Installing compiler toolchain via Homebrew..."
brew install gcc || true
# Homebrew installs gcc as gcc-{major}; create cc/gcc symlinks for source builds
gcc_bin="$(ls "${homebrew_prefix}/bin"/gcc-[0-9]* 2>/dev/null | sort -V | tail -1)"
if [[ -n "${gcc_bin}" ]]; then
  ln -sfn "${gcc_bin}" "${homebrew_prefix}/bin/gcc"
  ln -sfn "${gcc_bin}" "${homebrew_prefix}/bin/cc"
fi
eval "$("${homebrew_prefix}/bin/brew" shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

brew_packages=(
  antidote
  atuin
  bat
  btop
  fd
  file-formula
  fzf
  git
  jq
  make
  neovim
  node
  pigz
  ripgrep
  sqlite
  unzip
  uv
  vim
  yazi
  zellij
  zsh
)
echo "Installing packages via Homebrew: ${brew_packages[*]}"
brew install "${brew_packages[@]}"

if [[ ! -x "$(command -v bun 2>/dev/null)" ]]; then
  BUN_INSTALL="${HOME}/.bun" curl -fsSL https://bun.sh/install | bash
  ln -sfn "${HOME}/.bun/bin/bun" "${bin_dir}/bun"
  ln -sfn "${HOME}/.bun/bin/bun" "${bin_dir}/bunx"
fi

# ── Vendor assets (shell/editor configs) ──────────────────────────────
rm -rf "${vendor_home}" "${runtime_home}"
mkdir -p "${runtime_home}"
cp -R "${repo_root}/vendor" "${vendor_home}"
if [[ -d "${repo_root}/runtime/${flavor_name}/vendor" ]]; then
  cp -R "${repo_root}/runtime/${flavor_name}/vendor" "${runtime_vendor_home}"
fi

cat > "${shell_dir}/.zshrc" <<EOF
# ${flavor_name} bootstrap-managed zsh config
export OPENPOD_PREFIX="${prefix}"
export OPENPOD_FLAVOR="${flavor_name}"
export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_CONFIG_DIR="${config_home}"
export OPENPOD_DATA_HOME="${data_home}"
export OPENPOD_STATE_HOME="${state_home}"
export OPENPOD_CACHE_HOME="${cache_home}"
export OPENPOD_REPO_ROOT="${repo_root}"
export OPENPOD_VENDOR_HOME="${vendor_home}"
export OPENPOD_RUNTIME_HOME="${runtime_home}"
export OPENPOD_RUNTIME_VENDOR_HOME="${runtime_vendor_home}"
export OPENPOD_SHELL_DIR="${shell_dir}"
export OPENPOD_CLAUDE_REAL_BIN="${bin_dir}/claude-real"
export OPENPOD_CODEX_REAL_BIN="${bin_dir}/codex-real"
export OPENPOD_COPILOT_REAL_BIN="${bin_dir}/copilot-real"
export OPENPOD_GEMINI_REAL_BIN="${bin_dir}/gemini-real"
export OPENPOD_HOMEBREW_PREFIX="${homebrew_prefix}"
eval "\$(${homebrew_prefix}/bin/brew shellenv)"
export PATH="${bin_dir}:\$PATH"
export ZSH="${vendor_home}/zsh/ohmyzsh"
export ZSH_DISABLE_COMPFIX=true
export DISABLE_AUTO_UPDATE=true
export LANG="\${LANG:-C.UTF-8}"
export LC_ALL="\${LC_ALL:-C.UTF-8}"
export TERM="\${TERM:-xterm-256color}"
export UV_LINK_MODE=copy
ZSH_THEME=""
plugins=(git extract)
source "\${ZSH}/oh-my-zsh.sh"
source "${vendor_home}/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "${vendor_home}/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "${vendor_home}/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "${vendor_home}/zsh/powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f "${shell_dir}/.p10k.zsh" ]] || source "${shell_dir}/.p10k.zsh"
if command -v atuin >/dev/null 2>&1; then
  eval "\$(atuin init zsh --disable-up-arrow)"
fi
alias cc=clear
alias zj=zellij
function y() {
  local tmp="\$(mktemp -t yazi-cwd.XXXXXX)" cwd
  command yazi "\$@" --cwd-file="\$tmp"
  cwd="\$(command cat -- "\$tmp" 2>/dev/null)"
  [ "\$cwd" != "\$PWD" ] && [ -d "\$cwd" ] && builtin cd -- "\$cwd"
  rm -f -- "\$tmp"
}
EOF

cat > "${prefix}/env.sh" <<EOF
export OPENPOD_PREFIX="${prefix}"
export OPENPOD_FLAVOR="${flavor_name}"
export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_CONFIG_DIR="${config_home}"
export OPENPOD_DATA_HOME="${data_home}"
export OPENPOD_STATE_HOME="${state_home}"
export OPENPOD_CACHE_HOME="${cache_home}"
export OPENPOD_REPO_ROOT="${repo_root}"
export OPENPOD_VENDOR_HOME="${vendor_home}"
export OPENPOD_RUNTIME_HOME="${runtime_home}"
export OPENPOD_RUNTIME_VENDOR_HOME="${runtime_vendor_home}"
export OPENPOD_SHELL_DIR="${shell_dir}"
export OPENPOD_CLAUDE_REAL_BIN="${bin_dir}/claude-real"
export OPENPOD_CODEX_REAL_BIN="${bin_dir}/codex-real"
export OPENPOD_COPILOT_REAL_BIN="${bin_dir}/copilot-real"
export OPENPOD_GEMINI_REAL_BIN="${bin_dir}/gemini-real"
export OPENPOD_HOMEBREW_PREFIX="${homebrew_prefix}"
eval "\$(${homebrew_prefix}/bin/brew shellenv)"
export PATH="${bin_dir}:\$PATH"
export XDG_CONFIG_HOME="\${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_DATA_HOME="\${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_STATE_HOME="\${XDG_STATE_HOME:-${HOME}/.local/state}"
export XDG_CACHE_HOME="\${XDG_CACHE_HOME:-${HOME}/.cache}"
export UV_LINK_MODE=copy
EOF

cp "${repo_root}/config/.p10k.zsh" "${shell_dir}/.p10k.zsh"

export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_FLAVOR="${flavor_name}"
export OPENPOD_LAZYVIM_SOURCE_DIR="${vendor_home}/nvim/lazyvim-starter"
export OPENPOD_LAZYVIM_STARTER_COMMIT="803bc181d7c0d6d5eeba9274d9be49b287294d99"
export OPENPOD_NVM_CONFIG_DIR="${xdg_config_home}/nvim"
export OPENPOD_NVM_DATA_DIR="${xdg_data_home}/nvim"
export OPENPOD_NVM_STATE_DIR="${xdg_state_home}/nvim"
export OPENPOD_NVM_CACHE_DIR="${xdg_cache_home}/nvim"
export OPENPOD_NVM_OVERLAY_DIR="${repo_root}/config/nvim"
export OPENPOD_PYRIGHT_VERSION="1.1.408"
export OPENPOD_RUFF_VERSION="0.15.9"
export OPENPOD_HARLEQUIN_VERSION="2.5.2"
export OPENPOD_UV_BIN="${homebrew_prefix}/bin/uv"
export OPENPOD_UV_TOOL_DIR="${prefix}/opt/uv-tools"
export OPENPOD_REPO_ROOT="${repo_root}"
export OPENPOD_VENDOR_HOME="${vendor_home}"
export OPENPOD_RUNTIME_HOME="${runtime_home}"
export OPENPOD_RUNTIME_VENDOR_HOME="${runtime_vendor_home}"
export OPENPOD_CONFIG_HOME="${config_home}"
export OPENPOD_PREFIX="${prefix}"
export OPENPOD_SHELL_DIR="${shell_dir}"

bash "${repo_root}/build/install-python-dev-tools.sh"
bash "${repo_root}/build/install-lazyvim.sh"

bash "${repo_root}/runtime/${flavor_name}/install-harness.sh"

cat <<EOF
Bootstrap complete.

Prefix: ${prefix}
Bin dir: ${bin_dir}
Homebrew: ${homebrew_prefix}
Flavor: ${flavor_name}
Config home: ${config_home}

Next steps:
  source "${prefix}/env.sh"
  ${flavor_name}-shell
EOF
