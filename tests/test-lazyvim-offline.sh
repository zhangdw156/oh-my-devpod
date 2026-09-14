#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

export HOME="${tmp_dir}/home"
export XDG_CONFIG_HOME="${tmp_dir}/config"
export XDG_DATA_HOME="${tmp_dir}/data"
export XDG_STATE_HOME="${tmp_dir}/state"
export XDG_CACHE_HOME="${tmp_dir}/cache"
export OHMYDEVPOD_BUNDLE_ROOT="${repo_root}"
export OHMYDEVPOD_MIRROR_PROFILE=cn
mkdir -p "${HOME}" "${XDG_CONFIG_HOME}" "${tmp_dir}/bin"

# Reject downloads even when a plugin tries them through an external process.
real_git="$(command -v git)"
export OMD_OFFLINE_NETWORK_LOG="${tmp_dir}/network.log"
export OMD_OFFLINE_REAL_GIT="${real_git}"
cat > "${tmp_dir}/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
case " $* " in
  *' clone '*|*' fetch '*|*' pull '*|*' ls-remote '*)
    printf 'git %s\n' "$*" >> "${OMD_OFFLINE_NETWORK_LOG}"
    exit 97
    ;;
esac
exec "${OMD_OFFLINE_REAL_GIT}" "$@"
GIT
cat > "${tmp_dir}/bin/curl" <<'BLOCK'
#!/usr/bin/env bash
printf '%s %s\n' "$0" "$*" >> "${OMD_OFFLINE_NETWORK_LOG}"
exit 97
BLOCK
cp "${tmp_dir}/bin/curl" "${tmp_dir}/bin/wget"
chmod +x "${tmp_dir}/bin/"*
export PATH="${tmp_dir}/bin:${PATH}"

bash "${repo_root}/modules/tools/lazyvim.sh" install
bash "${repo_root}/modules/tools/lazyvim.sh" managed || fail "China install must be managed"
[[ -f "${XDG_CONFIG_HOME}/nvim/.omd-plugins/lazy.nvim/lua/lazy/init.lua" ]] ||
  fail "China install must include lazy.nvim"
[[ -f "${XDG_CONFIG_HOME}/nvim/.omd-plugins/LazyVim/lua/lazyvim/config/init.lua" ]] ||
  fail "China install must include LazyVim"

# An invalid payload must fail before moving existing configuration or data.
mkdir -p "${tmp_dir}/broken"
cp "${repo_root}/vendor/nvim/"{plugins.lock.json,SHA256SUMS} "${tmp_dir}/broken/"
printf 'corrupt\n' > "${tmp_dir}/broken/plugins.tar.gz"
printf 'preserve\n' > "${XDG_CONFIG_HOME}/nvim/user-file"
if OHMYDEVPOD_LAZYVIM_SOURCE_DIR="${repo_root}/vendor/nvim/lazyvim-starter" \
  OHMYDEVPOD_LAZYVIM_PLUGIN_ARCHIVE="${tmp_dir}/broken/plugins.tar.gz" \
  bash "${repo_root}/build/install-lazyvim.sh" >"${tmp_dir}/corrupt.log" 2>&1; then
  fail "installer must reject corrupt plugin payloads"
fi
[[ -f "${XDG_CONFIG_HOME}/nvim/user-file" ]] || fail "invalid payload must preserve the existing config"

nvim_bin="${OMD_TEST_NVIM_BIN:-$(command -v nvim || true)}"
if [[ -z "${nvim_bin}" ]]; then
  printf 'SKIP: real offline Neovim smoke test (nvim unavailable)\n'
  exit 0
fi
cat > "${tmp_dir}/check.lua" <<'LUA'
vim.schedule(function()
  local ok, err = pcall(function()
    assert(vim.v.errmsg == "", vim.v.errmsg)
    assert(type(LazyVim) == "table", "LazyVim did not initialize")
    local config = require("lazy.core.config")
    for name, plugin in pairs(config.plugins) do
      assert(plugin._.installed, "missing plugin: " .. name)
      assert(plugin._.is_local, "plugin requires GitHub: " .. name)
    end
    vim.cmd("edit " .. vim.env.XDG_STATE_HOME .. "/smoke.lua")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1" })
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.api.nvim_exec_autocmds("InsertEnter", {})
    assert(require("blink.cmp"), "completion did not load")
    assert(vim.wait(1000, function() return false end) == false)
    assert(vim.v.errmsg == "", vim.v.errmsg)
  end)
  if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
  end
  vim.cmd("qa!")
end)
LUA
"${nvim_bin}" --headless -c "luafile ${tmp_dir}/check.lua" >"${tmp_dir}/nvim.log" 2>&1 || {
  cat "${tmp_dir}/nvim.log" >&2
  fail "offline Neovim startup failed"
}
if [[ -s "${OMD_OFFLINE_NETWORK_LOG}" ]]; then
  cat "${OMD_OFFLINE_NETWORK_LOG}" >&2
  fail "offline startup attempted a download"
fi
if rg -n 'Error|Failed|E[0-9]{3}:' "${tmp_dir}/nvim.log"; then
  fail "offline Neovim reported a configuration error"
fi
printf 'offline LazyVim tests passed\n'
