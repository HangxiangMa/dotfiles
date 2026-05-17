return {
	"nvim-neotest/neotest",
	enabled = false,
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		-- adapter
		"nvim-neotest/neotest-python",
		"alfaix/neotest-gtest",
	},
	-- stylua: ignore
	keys = {
		{ "<leader>v",  "",                                                                              desc = "+neotest" },
		{ "<leader>va", function() require("neotest").run.attach() end,                                  desc = "Attach Nearest" },
		{ "<leader>vd", function() require("neotest").run.run({ strategy = "dap" }) end,                 desc = "Debug Nearest" },
		{ "<leader>vt", function() require("neotest").run.run(vim.fn.expand("%")) end,                   desc = "Run File" },
		{ "<leader>vT", function() require("neotest").run.run(vim.uv.cwd()) end,                         desc = "Run All Test Files" },
		{ "<leader>vr", function() require("neotest").run.run() end,                                     desc = "Run Nearest" },
		{ "<leader>vl", function() require("neotest").run.run_last() end,                                desc = "Run Last" },
		{ "<leader>vs", function() require("neotest").summary.toggle() end,                              desc = "Toggle Summary" },
		{ "<leader>vo", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
		{ "<leader>vO", function() require("neotest").output_panel.toggle() end,                         desc = "Toggle Output Panel" },
		{ "<leader>vS", function() require("neotest").run.stop() end,                                    desc = "Stop" },
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
