return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPre",
	config = function()
		require("gitsigns").setup({
			signs = {
				add = { text = "│" },
				change = { text = "│" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
				untracked = { text = "┆" },
			},
			signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
			numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
			linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
			word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
			watch_gitdir = {
				follow_files = true,
			},
			attach_to_untracked = true,
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
				delay = 500,
				ignore_whitespace = false,
			},
			current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
			sign_priority = 6,
			update_debounce = 100,
			status_formatter = nil, -- Use default
			-- gitsigns stops diffing files longer than this. Aligned with the
			-- bigfile line threshold so oversized files skip diff entirely.
			max_file_length = 12000,
			preview_config = {
				border = "single",
				style = "minimal",
				relative = "cursor",
				row = 0,
				col = 1,
			},
			on_attach = function(bufnr)
				-- Disable per-line git blame on large buffers by line count
				-- rather than the bigfile filetype: current_line_blame spawns a
				-- git blame on every new cursor line, which is the main
				-- large-file cost here even when max_file_length still allows
				-- signs. Line-count keying also covers buffers that never got
				-- the bigfile filetype.
				if vim.api.nvim_buf_line_count(bufnr) > 12000 or vim.bo[bufnr].filetype == "bigfile" then
					vim.b[bufnr].gitsigns_current_line_blame = false
				end
			end,
		})
	end,
}
