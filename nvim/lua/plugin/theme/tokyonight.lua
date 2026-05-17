return {
	"folke/tokyonight.nvim",
	enabled = false,
	lazy = false,
	priority = 1000,
	config = function()
		-- load the colorscheme here
		vim.cmd([[colorscheme tokyonight-moon]])
	end,
}
