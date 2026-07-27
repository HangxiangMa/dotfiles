return {
	"nvim-treesitter/nvim-treesitter-context",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("treesitter-context").setup({
			enable = true,
			-- Cap the context window height. 0 = unlimited, which on deeply
			-- nested code (common in large C files) can push many lines of
			-- context and recompute them on every cursor move.
			max_lines = 4,
			min_window_height = 0,
			line_numbers = true,
			multiline_threshold = 10,
			trim_scope = "outer",
			mode = "cursor",
			separator = nil,
			zindex = 10,
			on_attach = function(buf)
				-- Skip large buffers by line count as well as the bigfile
				-- filetype: context recomputes by walking the tree upward on
				-- every CursorMoved.
				return vim.api.nvim_buf_line_count(buf) <= 12000 and vim.bo[buf].filetype ~= "bigfile"
			end,
		})
	end,
}
