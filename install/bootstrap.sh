#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="user"
prefix_default="${HOME}/.local/openpod"
prefix="${OPENPOD_PREFIX:-${prefix_default}}"

usage() {
  cat <<'EOF'
Usage: bash install/bootstrap.sh [--user] [--system] [--prefix PATH]

Bootstrap an openpod-like environment on a Linux host or inside an existing container.

Options:
  --user           Install into a user-owned prefix (default)
  --system         Install into /opt/openpod with binaries under /usr/local/bin
  --prefix PATH    Override the installation prefix
  -h, --help       Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      mode="user"
      prefix="${OPENPOD_PREFIX:-${HOME}/.local/openpod}"
      shift
      ;;
    --system)
      mode="system"
      prefix="${OPENPOD_PREFIX:-/opt/openpod}"
      shift
      ;;
    --prefix)
      prefix="$2"
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

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "bootstrap mode currently supports Linux only" >&2
  exit 1
fi

if ! command -v dpkg >/dev/null 2>&1 || ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "bootstrap mode currently requires Debian/Ubuntu-style dpkg tools" >&2
  exit 1
fi

for cmd in bash curl git tar sha256sum install zsh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ "$mode" == "system" && "$(id -u)" -ne 0 ]]; then
  echo "--system requires root privileges" >&2
  exit 1
fi

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
    config_home="/root/.config/opencode"
  else
    config_home="${HOME}/.config/opencode"
  fi
fi

if [[ -z "${data_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    data_home="/root/.local/share/openpod"
  else
    data_home="${HOME}/.local/share/openpod"
  fi
fi

if [[ -z "${state_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    state_home="/root/.local/state/openpod"
  else
    state_home="${HOME}/.local/state/openpod"
  fi
fi

if [[ -z "${cache_home}" ]]; then
  if [[ "$mode" == "system" ]]; then
    cache_home="/root/.cache/openpod"
  else
    cache_home="${HOME}/.cache/openpod"
  fi
fi

vendor_home="${prefix}/vendor"
plugin_dir="${config_home}/plugins"
skills_link="${config_home}/skills"
shell_dir="${prefix}/shell"
asset_root="${repo_root}/vendor/releases"
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

mkdir -p "${prefix}" "${bin_dir}" "${config_home}" "${plugin_dir}" "${data_home}" "${state_home}" "${cache_home}" "${shell_dir}"
rm -rf "${vendor_home}"
cp -R "${repo_root}/vendor" "${vendor_home}"

cat > "${shell_dir}/.zshrc" <<EOF
# openpod bootstrap-managed zsh config
export OPENPOD_PREFIX="${prefix}"
export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_CONFIG_DIR="${config_home}"
export OPENPOD_DATA_HOME="${data_home}"
export OPENPOD_STATE_HOME="${state_home}"
export OPENPOD_CACHE_HOME="${cache_home}"
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
export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_CONFIG_DIR="${config_home}"
export OPENPOD_DATA_HOME="${data_home}"
export OPENPOD_STATE_HOME="${state_home}"
export OPENPOD_CACHE_HOME="${cache_home}"
export PATH="${bin_dir}:\$PATH"
export XDG_CONFIG_HOME="\${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_DATA_HOME="\${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_STATE_HOME="\${XDG_STATE_HOME:-${HOME}/.local/state}"
export XDG_CACHE_HOME="\${XDG_CACHE_HOME:-${HOME}/.cache}"
export UV_LINK_MODE=copy
EOF

cp "${repo_root}/config/.p10k.zsh" "${shell_dir}/.p10k.zsh"
cp "${repo_root}/config/opencode.json" "${config_home}/config.json"
ln -sfn "${vendor_home}/opencode/packages/superpowers/.opencode/plugins/superpowers.js" "${plugin_dir}/superpowers.js"
ln -sfn "${vendor_home}/opencode/skills" "${skills_link}"

export OPENPOD_ASSET_ROOT="${asset_root}"
export OPENPOD_BIN_DIR="${bin_dir}"
export OPENPOD_BTOP_DIR="${prefix}/opt/btop"
export OPENPOD_ANTIDOTE_DIR="${prefix}/opt/antidote"
export OPENPOD_NEOVIM_DIR="${prefix}/opt/neovim"
export OPENPOD_LAZYVIM_SOURCE_DIR="${vendor_home}/nvim/lazyvim-starter"
export OPENPOD_LAZYVIM_STARTER_COMMIT="803bc181d7c0d6d5eeba9274d9be49b287294d99"
export OPENPOD_NVM_CONFIG_DIR="${xdg_config_home}/nvim"
export OPENPOD_NVM_DATA_DIR="${xdg_data_home}/nvim"
export OPENPOD_NVM_STATE_DIR="${xdg_state_home}/nvim"
export OPENPOD_NVM_CACHE_DIR="${xdg_cache_home}/nvim"

bash "${repo_root}/build/install-btop.sh"
bash "${repo_root}/build/install-antidote.sh"
bash "${repo_root}/build/install-zellij.sh"
bash "${repo_root}/build/install-yazi.sh"
bash "${repo_root}/build/install-neovim.sh"
bash "${repo_root}/build/install-lazyvim.sh"

if command -v fdfind >/dev/null 2>&1 && [[ ! -e "${bin_dir}/fd" ]]; then
  ln -sfn "$(command -v fdfind)" "${bin_dir}/fd"
fi

missing_lazyvim_deps=()
for cmd in rg fd unzip make gcc; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    missing_lazyvim_deps+=("${cmd}")
  fi
done

if [[ ! -x "${bin_dir}/uv" ]]; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${bin_dir}" UV_NO_MODIFY_PATH=1 sh
fi

need_opencode_install=0
if [[ ! -x "${bin_dir}/opencode" ]]; then
  need_opencode_install=1
elif ! "${bin_dir}/opencode" --version >/dev/null 2>&1; then
  need_opencode_install=1
fi

if [[ "${need_opencode_install}" == "1" ]]; then
  opencode_home="$(mktemp -d)"
  env HOME="${opencode_home}" PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'
  install -m 0755 "${opencode_home}/.opencode/bin/opencode" "${bin_dir}/opencode"
  rm -rf "${opencode_home}"
fi

cat > "${bin_dir}/openpod-shell" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "${prefix}/env.sh"
if [[ \$# -eq 0 ]]; then
  exec env ZDOTDIR="${shell_dir}" zsh -i
else
  exec env ZDOTDIR="${shell_dir}" zsh "\$@"
fi
EOF
chmod 0755 "${bin_dir}/openpod-shell"

cat <<EOF
Bootstrap complete.

Prefix: ${prefix}
Bin dir: ${bin_dir}
OpenCode config: ${config_home}

Next steps:
  source "${prefix}/env.sh"
  openpod-shell

Notes:
- Existing ~/.zshrc was not modified.
- Shell config lives under ${shell_dir}.
EOF

if ((${#missing_lazyvim_deps[@]} > 0)); then
  printf ' - LazyVim optional dependencies not found: %s\n' "${missing_lazyvim_deps[*]}"
  echo "   First nvim launch still works, but some picker/build features may be limited until those commands are installed."
fi
