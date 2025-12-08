-- Load NvChad defaults
require("nvchad.configs.lspconfig").defaults()

local mason_lspconfig = require "mason-lspconfig"

-- Automatically enable ALL servers installed via Mason UI
mason_lspconfig.setup {
  -- Don't specify ensure_installed - manage via Mason UI instead
  ensure_installed = {},

  -- Automatically enable any server installed through Mason
  automatic_enable = true,
}

-- Setting up Pyright using vim.lsp
vim.lsp.config.pyright = {
  on_attach = function(client, bufnr)
    -- Disable Pyright's formatting (Ruff handles it)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic", -- gives type checking errors but not linting
        diagnosticMode = "openFilesOnly",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
}

-- Setting up Ruff (linter and formatter) using vim.lsp
vim.lsp.config.ruff = {
  on_attach = function(client, bufnr)
    -- Disable Ruff's completion feature, let Pyright handle it
    client.server_capabilities.completionProvider = false
  end,
}

-- -- Configure these servers to actually be launched when needed
-- vim.lsp.set_config("pyright", vim.lsp.config.pyright)
-- vim.lsp.set_config("ruff", vim.lsp.config.ruff)
