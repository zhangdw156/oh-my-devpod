-- The China profile loads pinned plugins shipped with OMD.
local bundle = vim.fn.stdpath("config") .. "/.omd-plugins"
vim.opt.rtp:prepend(bundle .. "/lazy.nvim")
local plugins = vim.json.decode(table.concat(vim.fn.readfile(bundle .. "/plugins.lock.json"), "\n"))
local spec = {
  { "LazyVim/LazyVim", dir = bundle .. "/LazyVim", import = "lazyvim.plugins" },
  { import = "plugins" },
}
for name, plugin in pairs(plugins) do
  spec[#spec + 1] = { plugin.repo, name = name, dir = bundle .. "/" .. name, pin = true, build = false }
end
require("lazy").setup({
  spec = spec,
  defaults = { lazy = false, version = false },
  install = { missing = false, colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  pkg = { enabled = false },
})
