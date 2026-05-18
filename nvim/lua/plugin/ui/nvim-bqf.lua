-- Better quickfix window: preview, fuzzy filter, fzf integration.
-- Loaded only when a quickfix buffer opens.
return {
	"kevinhwang91/nvim-bqf",
	ft = "qf",
	opts = {
		auto_enable = true,
		preview = {
			win_height = 12,
			win_vheight = 12,
			delay_syntax = 80,
			border = "rounded",
			show_title = false,
			should_preview_cb = function(bufnr)
				-- skip preview for huge files / fugitive-style buffers
				local fsize = vim.fn.getfsize(vim.api.nvim_buf_get_name(bufnr))
				if fsize > 100 * 1024 then
					return false
				end
				return true
			end,
		},
		func_map = {
			drop = "o",
			openc = "O",
			split = "<C-s>",
			vsplit = "<C-v>",
			tabdrop = "<C-t>",
			tab = "t",
			tabc = "",
			ptogglemode = "z,",
			fzffilter = "zf",
		},
		filter = {
			fzf = {
				action_for = { ["ctrl-s"] = "split", ["ctrl-t"] = "tab drop" },
				extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
			},
		},
	},
}
