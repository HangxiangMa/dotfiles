return {
	-- indent guides for Neovim
	{
		"lukas-reineke/indent-blankline.nvim",
		event = { "BufReadPre", "BufNewFile" },
		tag = "v3.8.7",
		main = "ibl",
		config = function()
			local hooks = require("ibl.hooks")
			local highlight = {
				"RainbowRed",
				"RainbowYellow",
				"RainbowBlue",
				"RainbowOrange",
				"RainbowGreen",
				"RainbowViolet",
				"RainbowCyan",
			}
			-- create the highlight groups in the highlight setup hook, so they are reset
			-- every time the colorscheme changes
			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)
			hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
			hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_tab_indent_level)
			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
			require("ibl").setup({
				indent = {
					char = "│",
					-- tab_char = "│",
					tab_char = "┇",
				},
				whitespace = {
					highlight = {
						"Whitespace",
					},
					remove_blankline_trail = false,
				},
				scope = {
					enabled = true,
					show_exact_scope = true,
					highlight = highlight,
				},
				exclude = {
					filetypes = {
						"help",
						"alpha",
						"dashboard",
						"NvimTree",
						"neo-tree",
						"trouble",
						"lazy",
						"mason",
						"notify",
						"toggleterm",
						"lazyterm",
					},
				},
			})
		end,
	},
}
