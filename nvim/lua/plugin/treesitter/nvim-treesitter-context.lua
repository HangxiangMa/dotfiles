return {
	"nvim-treesitter/nvim-treesitter-context",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("treesitter-context").setup({
			enable = true,
			max_lines = 0,
			min_window_height = 0,
			line_numbers = true,
			multiline_threshold = 10,
			trim_scope = "outer",
			mode = "cursor",
			separator = nil,
			zindex = 10,
			on_attach = function(buf)
				return not require("core.crisp").isBigFile(buf)
			end,
		})
	end,
}
