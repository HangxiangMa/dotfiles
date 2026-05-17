return {
	"kawre/leetcode.nvim",
	enabled = false,
	version = "v0.3.x",
	lazy = "leetcode.nvim" ~= vim.fn.argv()[1],
	build = ":TSUpdate html",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",

		-- optional
		"nvim-treesitter/nvim-treesitter",
		"rcarriga/nvim-notify",
		{ "nvim-tree/nvim-web-devicons", lazy = false },
	},
	config = function()
		require("leetcode").setup({
			arg = "leetcode.nvim",
			lang = "cpp",
			cn = { -- leetcode.cn
				enabled = true,
				translator = false,
				translate_problems = false,
			},

			injector = {
				["cpp"] = {
					before = {
						"#include <bits/stdc++.h>",
						"using namespace std;",
					},
				},
			},
			description = {
				position = "left",
				width = "30%",
				show_stats = true,
			},
			image_support = false,

			keys = {
				toggle = { "q" }, ---@type string|string[]
				confirm = { "<CR>" }, ---@type string|string[]

				reset_testcases = "R", ---@type string
				use_testcase = "U", ---@type string
				focus_testcases = "H", ---@type string
				focus_result = "L", ---@type string
			},
		})
	end,
}
