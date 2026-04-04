if lazyvim_docs then
  vim.g.lazyvim_python_lsp = "pyright"
  vim.g.lazyvim_python_ruff = "ruff"
end

return {
  { import = "lazyvim.plugins.extras.lang.python" },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      for _, server in ipairs({ "pyright", "ruff" }) do
        opts.servers[server] = opts.servers[server] or {}
        opts.servers[server].mason = false
      end
    end,
  },
}
