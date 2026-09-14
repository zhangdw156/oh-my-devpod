-- External tools and parsers can be installed explicitly when needed.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
  { "saghen/blink.cmp", opts = { fuzzy = { implementation = "lua" } } },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      for _, server in pairs(opts.servers) do
        if type(server) == "table" then
          server.mason = false
        end
      end
      opts.servers.lua_ls = { enabled = vim.fn.executable("lua-language-server") == 1, mason = false }
    end,
  },
}
