local options = {
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "ruff_organize_imports", "ruff_fix", "ruff_format" },
		zsh = { "beautysh" },
		bash = { "shfmt" },
		sh = { "shfmt" },
		cpp = { "clang-format" },
		qmd = { "panache" },
		markdown = { "panache" },
		md = { "panache" },

		-- Default: everything else uses prettierd
		["_"] = { "prettierd" },
	},

	formatters = {
		panache = { command = "panache", args = { "format" }, stdin = true },
	},

	format_on_save = function(bufnr)
		local skip = { txt = true, log = true, gitcommit = true }
		if skip[vim.bo[bufnr].filetype] then
			return nil
		end
		return { timeout_ms = 5000, lsp_format = "fallback" }
	end,
}

return options
