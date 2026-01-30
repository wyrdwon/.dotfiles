local options = {
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		-- rust = { "rust_analyzer", lsp_format = "fallback" },

		-- Default: everything else uses prettierd
		["_"] = { "prettierd" },
	},

	format_on_save = {
		timeout_ms = 500,
		lsp_fallback = true, -- Use LSP formatting as fallback if formatter fails
	},
}

-- Exclusions: these filetypes won't have any formatters
local excluded = { "txt", "log", "gitcommit" }

for _, ft in ipairs(excluded) do
	options.formatters_by_ft[ft] = {}
end

return options
