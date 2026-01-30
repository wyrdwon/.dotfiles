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

vim.lsp.config.basedpyright = {
	settings = {
		python = {
			analysis = {
				typeCheckingMode = "basic",
				diagnosticMode = "openFilesOnly",
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
			},
		},
	},
}

-- -- Configure these servers to actually be launched when needed
-- vim.lsp.set_config("pyright", vim.lsp.config.pyright)
-- vim.lsp.set_config("ruff", vim.lsp.config.ruff)
