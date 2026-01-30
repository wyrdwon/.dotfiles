return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePRe", "BufNewFile" }, -- uncomment for format on save
		opts = require "configs.conform",
	},

	{
		"neovim/nvim-lspconfig",
		config = function()
			require "configs.lspconfig"
		end,
	},

	-- Mason for managing LSP servers
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},

	-- Mason-LSPConfig for automatic LSP configuration
	{
		"mason-org/mason-lspconfig.nvim",
		opts = {},
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			"neovim/nvim-lspconfig",
		},
	},

	{
		"f-person/git-blame.nvim",
		-- load the plugin at startup
		event = "VeryLazy",
		-- Because of the keys part, you will be lazy loading this plugin.
		-- The plugin will only load once one of the keys is used.
		-- If you want to load the plugin at startup, add something like event = "VeryLazy",
		-- or lazy = false. One of both options will work.
		opts = {
			-- your configuration comes here
			-- for example
			enabled = true, -- if you want to enable the plugin
			message_template = " <author> • <date> • <sha>", -- template for the blame message, check the Message template section for more options
			date_format = "%d-%m-%Y %H:%M:%S", -- template for the date, check Date format section for more options
			virtual_text_column = 1, -- virtual text start column, check Start virtual text at column section for more options
		},
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			local ibl = require "ibl"
			local hooks = require "ibl.hooks"

			local rainbow_highlight = {
				"RainbowRed",
				"RainbowYellow",
				"RainbowBlue",
				"RainbowOrange",
				"RainbowGreen",
				"RainbowViolet",
				"RainbowCyan",
			}

			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				-- Base indent / whitespace
				vim.api.nvim_set_hl(0, "MyIblIndent", { fg = "#5A6B7D" })
				vim.api.nvim_set_hl(0, "MyIblWhitespace", { fg = "#98A6B2" })

				-- Rainbow colors (shared)
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)

			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)

			-- REQUIRED for rainbow-delimiters.nvim
			vim.g.rainbow_delimiters = {
				highlight = rainbow_highlight,
			}

			ibl.setup {
				indent = {
					char = "│",
					highlight = { "MyIblIndent" },
				},
				scope = {
					enabled = true,
					highlight = rainbow_highlight,
				},
				whitespace = {
					highlight = { "MyIblWhitespace" },
				},
			}
		end,
	},

	{
		"HiPhish/rainbow-delimiters.nvim",
		event = "VeryLazy",
	},

	{
		"Djancyp/better-comments.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = "BufReadPost", -- trigger plugin load after a buffer is read
		config = function()
			require("better-comment").Setup()

			local highlight_groups = {
				TODO = { fg = "white", bg = "#0a7aca", bold = true },
				FIX = { fg = "white", bg = "#f44747", bold = true },
				WARNING = { fg = "white", bg = "#ff8800", bold = true },
				NOTE = { fg = "white", bg = "#6f42c1", bold = true },
				HACK = { fg = "white", bg = "#e83e8c", bold = true },
				PERF = { fg = "white", bg = "#20c997", bold = true },
				TEST = { fg = "white", bg = "#17a2b8", bold = true },
			}

			for tag, hl in pairs(highlight_groups) do
				vim.api.nvim_set_hl(0, "BetterComments" .. tag, {
					fg = hl.fg,
					bg = hl.bg,
					bold = hl.bold,
				})
			end
		end,
	},

	-- fix this
	{ "nvim-mini/mini.nvim", version = "*" },

	{
		"folke/zen-mode.nvim",
		cmd = "ZenMode",
		config = function()
			require("zen-mode").setup()
		end,
	},

	{ import = "nvchad.blink.lazyspec" },

	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"vim",
				"lua",
				"vimdoc",
				"html",
				"css",
			},
		},
		init = function()
			require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
				local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
				local filename = vim.fn.fnamemodify(filepath, ":t")
				return string.match(filename, ".*mise.*%.toml$") ~= nil
			end, { force = true, all = false })
		end,
	},

	{
		"jmbuhr/otter.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				pattern = { "toml" },
				group = vim.api.nvim_create_augroup("EmbedToml", {}),
				callback = function()
					require("otter").activate()
				end,
			})
		end,
	},
	-- ought to replace the prisma/vim-prisma + coc-prisma combo
	-- bro is failing lol
	-- {
	--   "dastanaron/prisma.nvim",
	--   event = "VeryLazy",
	--   dependencies = {
	--     "williamboman/mason.nvim",
	--     "neovim/nvim-lspconfig",
	--     "nvim-treesitter/nvim-treesitter",
	--   },
	--   config = function()
	--     local nvlsp = require "nvchad.configs.lspconfig"
	--     require("prisma").setup {
	--       lsp = {
	--         on_attach = function(client, bufnr)
	--           nvlsp.on_attach(client, bufnr)
	--         end,
	--         capabilities = nvlsp.capabilities,
	--         on_init = nvlsp.on_init,
	--       },
	--     }
	--   end,
	-- },
	{
		"prisma/vim-prisma",
		ft = "prisma",
	},

	-- -- plugins/plenary.lua
	-- {
	--   {
	--     "nvim-lua/plenary.nvim",
	--     lazy = true, -- or `false` depending on how often you use it
	--     -- no build step needed, it's pure Lua
	--     -- no setup function necessary, since plenary is mostly utilities you `require(...)` when needed
	--   },
	-- },

	{
		"pmizio/typescript-tools.nvim",
		ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},

	{
		"karloskar/poetry-nvim",
		config = function()
			require("poetry-nvim").setup()
		end,
	},
	{
		"gisketch/triforce.nvim",
		dependencies = { "nvzone/volt" },
		lazy = false,
		config = function()
			require("triforce").setup {
				-- Optional: Add your configuration here
				keymap = {
					show_profile = "<leader>tp", -- Open profile with <leader>tp
				},
			}
		end,
	},
	-- Lazy.nvim
	{
		"xvzc/chezmoi.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("chezmoi").setup {
				-- your configurations
			}
		end,
	},

	{
		"uga-rosa/ccc.nvim",
	},
}
