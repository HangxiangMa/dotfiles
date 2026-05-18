-- vim-slime: send text from nvim to a tmux pane (REPL/shell).
-- Target defaults to the previously active tmux pane ("{last}"); use
-- <leader>sc to pick a different target interactively.
return {
	"jpalardy/vim-slime",
	keys = {
		{ "<leader>ss", "<Plug>SlimeMotionSend", desc = "Slime: send (motion)" },
		{ "<leader>ss", "<Plug>SlimeRegionSend", mode = "x", desc = "Slime: send selection" },
		{ "<leader>sl", "<Plug>SlimeLineSend", desc = "Slime: send line" },
		{ "<leader>sp", "<Plug>SlimeParagraphSend", desc = "Slime: send paragraph" },
		{ "<leader>sc", "<cmd>SlimeConfig<CR>", desc = "Slime: configure target pane" },
	},
	init = function()
		vim.g.slime_target = "tmux"
		vim.g.slime_default_config = {
			socket_name = "default",
			target_pane = "{last}",
		}
		vim.g.slime_dont_ask_default = 1
		vim.g.slime_no_mappings = 1
		vim.g.slime_bracketed_paste = 1
	end,
}
