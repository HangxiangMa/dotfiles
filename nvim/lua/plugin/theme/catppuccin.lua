return {
	"catppuccin/nvim",
	enabled = false,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	name = "catppuccin",
	priority = 1000,
	config = function()
		-- load the colorscheme here
		-- catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
		vim.cmd([[colorscheme catppuccin-frappe]])
	end,
}
