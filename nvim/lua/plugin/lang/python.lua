return {
	-- python REPL: [disabled now]
	{
		"geg2102/nvim-python-repl",
		enabled = false,
		dependencies = "nvim-treesitter",
		ft = { "python", "lua", "scala" },
		config = function()
			require("nvim-python-repl").setup({
				execute_on_send = false,
				vsplit = false,
			})
		end,
	},

	-- python syntax
	{
		"vim-python/python-syntax",
		event = { "BufReadPre", "BufNewFile" },
		ft = { "python" },
		config = function()
			vim.g.python_version_2 = 0
			vim.b.python_version_2 = 0
			vim.g.python_highlight_all = 1
		end,
	},
}
