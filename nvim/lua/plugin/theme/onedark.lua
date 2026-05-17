-- atom one dark colortheme
return {
	"navarasu/onedark.nvim",
	enabled = true,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	priority = 1000, -- make sure to load this before all the other start plugins
	config = function()
		-- load the colorscheme here
		require("onedark").setup({
			style = "dark",
			colors = {
				deep_grey = "#494f59",
			},
			highlights = {
				GitSignsCurrentLineBlame = { fg = "$deep_grey" },
			}, -- Override highlight groups
		})
		vim.cmd([[colorscheme onedark]])
	end,
}
