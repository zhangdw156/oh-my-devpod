#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" path="$2"
  grep -Fq "${needle}" "${path}" || fail "expected '${needle}' in ${path}"
}

home="${tmp_dir}/home"
config_home="${tmp_dir}/config"
state_dir="${tmp_dir}/state"
managed_dir="${state_dir}/managed"
brew_prefix="${tmp_dir}/linuxbrew"
mkdir -p \
  "${home}" \
  "${config_home}" \
  "${managed_dir}" \
  "${brew_prefix}/bin" \
  "${brew_prefix}/Cellar/uv/1.0" \
  "${brew_prefix}/Cellar/micromamba/1.0"
printf '#!/usr/bin/env bash\nexit 0\n' > "${brew_prefix}/bin/brew"
chmod +x "${brew_prefix}/bin/brew"

cat > "${managed_dir}/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${brew_prefix}
EOF
for component in uv micromamba; do
  cat > "${managed_dir}/${component}" <<EOF
managed_by=oh-my-devpod
component=${component}
kind=brew-formula
artifact=${component}
EOF
done

export HOME="${home}"
export XDG_CONFIG_HOME="${config_home}"
export OHMYDEVPOD_STATE_DIR="${state_dir}"
export OHMYDEVPOD_BREW_BIN="${brew_prefix}/bin/brew"

# shellcheck source=../modules/lib/source-config.sh
source "${repo_root}/modules/lib/source-config.sh"

omd_source_config_apply gitee

brew_env="${brew_prefix}/etc/homebrew/brew.env"
uv_config="${config_home}/uv/uv.toml"
pip_config="${config_home}/pip/pip.conf"
mamba_config="${home}/.mambarc"
for path in "${brew_env}" "${uv_config}" "${pip_config}" "${mamba_config}"; do
  [[ -f "${path}" ]] || fail "missing managed native source config: ${path}"
done
assert_contains 'HOMEBREW_CORE_GIT_REMOTE=https://mirrors.ustc.edu.cn/homebrew-core.git' "${brew_env}"
assert_contains 'https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple' "${uv_config}"
assert_contains 'index-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple' "${pip_config}"
assert_contains 'channels:' "${mamba_config}"
assert_contains '  - conda-forge' "${mamba_config}"

snapshot="${tmp_dir}/snapshot"
mkdir -p "${snapshot}"
omd_source_config_snapshot "${snapshot}"
omd_source_config_apply github
for path in "${brew_env}" "${uv_config}" "${pip_config}" "${mamba_config}"; do
  [[ ! -e "${path}" ]] || fail "upstream profile should remove managed file: ${path}"
done
omd_source_config_restore "${snapshot}"
for path in "${brew_env}" "${uv_config}" "${pip_config}" "${mamba_config}"; do
  [[ -f "${path}" ]] || fail "restore should recover native source config: ${path}"
done

printf '# user modification\n' >> "${uv_config}"
if omd_source_config_apply github >/dev/null 2>&1; then
  fail "source switching should reject a modified managed uv config"
fi
assert_contains '# user modification' "${uv_config}"
sed -i.bak '$d' "${uv_config}"
rm -f "${uv_config}.bak"

omd_module_unmark_managed uv
omd_source_config_remove_component uv
[[ ! -e "${uv_config}" ]] || fail "uv uninstall should remove its managed native config"
[[ -e "${pip_config}" ]] ||
  fail "pip config should remain while managed micromamba is installed"

omd_module_unmark_managed micromamba
omd_source_config_remove_component micromamba
[[ ! -e "${mamba_config}" ]] ||
  fail "micromamba uninstall should remove its managed native config"
[[ ! -e "${pip_config}" ]] ||
  fail "pip config should be removed after the last managed Python environment tool"

external_home="${tmp_dir}/external-home"
external_config="${tmp_dir}/external-config"
external_state="${tmp_dir}/external-state"
mkdir -p "${external_home}" "${external_config}" "${external_state}/managed"
HOME="${external_home}" \
  XDG_CONFIG_HOME="${external_config}" \
  OHMYDEVPOD_STATE_DIR="${external_state}" \
  bash -c '
    source "$1"
    omd_source_config_apply gitee
  ' _ "${repo_root}/modules/lib/source-config.sh"
[[ ! -e "${external_config}/uv/uv.toml" ]] ||
  fail "external uv installations should not receive managed config"
[[ ! -e "${external_home}/.mambarc" ]] ||
  fail "external micromamba installations should not receive managed config"

symlink_home="${tmp_dir}/symlink-home"
symlink_config="${tmp_dir}/symlink-config"
symlink_external="${tmp_dir}/symlink-external"
symlink_state="${tmp_dir}/symlink-state"
symlink_brew="${tmp_dir}/symlink-brew"
mkdir -p \
  "${symlink_home}" \
  "${symlink_config}" \
  "${symlink_external}" \
  "${symlink_state}/managed" \
  "${symlink_brew}/bin" \
  "${symlink_brew}/Cellar/uv/1.0"
printf '#!/usr/bin/env bash\nexit 0\n' > "${symlink_brew}/bin/brew"
chmod +x "${symlink_brew}/bin/brew"
cat > "${symlink_state}/managed/uv" <<EOF
managed_by=oh-my-devpod
component=uv
kind=brew-formula
artifact=uv
brew_prefix=${symlink_brew}
EOF
ln -s "${symlink_external}" "${symlink_config}/uv"
if HOME="${symlink_home}" \
  XDG_CONFIG_HOME="${symlink_config}" \
  OHMYDEVPOD_BREW_BIN="${symlink_brew}/bin/brew" \
  OHMYDEVPOD_STATE_DIR="${symlink_state}" \
  bash -c '
    source "$1"
    omd_source_config_apply gitee
  ' _ "${repo_root}/modules/lib/source-config.sh" >/dev/null 2>&1; then
  fail "source config should reject symlinked parent directories"
fi
[[ ! -e "${symlink_external}/uv.toml" ]] ||
  fail "source config must not write through a symlinked parent"

echo "source config tests passed"
