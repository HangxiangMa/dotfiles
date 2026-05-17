return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = { enabled = true },
		dashboard = { enabled = false },
		indent = { enabled = false },
		input = { enabled = true },
		notifier = { enabled = true },
		picker = { enabled = true }, -- powers Snacks.picker.smart (frecency)
		quickfile = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = true },
	},
	keys = {
		{
			"<leader>fo",
			function()
				require("snacks").picker.smart()
			end,
			desc = "Smart Open (frecency)",
		},
		{
			"<leader>fO",
			function()
				require("snacks").picker.smart({ cwd = vim.fn.getcwd() })
			end,
			desc = "Smart Open (CWD)",
		},
	},
}
