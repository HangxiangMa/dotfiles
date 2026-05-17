return {
	"nvim-neotest/neotest",
	enabled = false,
	lazy = true,
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		-- adapter
		"nvim-neotest/neotest-python",
		"alfaix/neotest-gtest",
	},
	config = function()
		require("neotest").setup({
			adapters = {
				require("neotest-python")({
					dap = { justMyCode = false },
				}),
				require("rustaceanvim.neotest"),
				require("neotest-gtest"),
			},
		})
	end,
}
