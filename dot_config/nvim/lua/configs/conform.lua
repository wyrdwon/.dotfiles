local web = { "prettierd" }

local options = {
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "ruff_fix", "ruff_organize_imports", "ruff_format" },
		sh = { "shfmt" }, -- also .bashrc/.profile (ft=sh, b:is_bash)
		bash = { "shfmt" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		cuda = { "clang-format" },
		rust = { "rustfmt" }, -- ships with the rustup default profile
		julia = {}, -- deliberate: falls through to LSP formatting
		toml = { "tombi" }, -- Cargo.toml, pyproject.toml, Project.toml
		quarto = { "panache" },
		markdown = { "panache" },

		javascript = web,
		javascriptreact = web,
		typescript = web,
		typescriptreact = web,
		json = web,
		jsonc = web,
		yaml = web,
		html = web,
		css = web,
		scss = web,
	},

	formatters = {
		panache = { command = "panache", args = { "format" }, stdin = true },
	},

	format_on_save = function(bufnr)
		local skip = { text = true, log = true, gitcommit = true, gitrebase = true }
		if skip[vim.bo[bufnr].filetype] then
			return nil
		end
		return { timeout_ms = 5000, lsp_format = "fallback" }
	end,
}

return options
