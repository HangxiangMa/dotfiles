-- persistence.nvim: single source of truth for nvim sessions. Saves on
-- VimLeavePre per cwd, autoloads on startup when nvim is launched with
-- no file/stdin args — which is exactly how tmux-resurrect re-launches
-- it, so reattaching a restored tmux session brings the editor back too.
return {
	"folke/persistence.nvim",
	lazy = false,
	priority = 100,
	opts = {
		options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
	},
	config = function(_, opts)
		require("persistence").setup(opts)
		-- Autoload on bare `nvim` (no file args). `nvim foo.c` skips it.
		if #vim.fn.argv() == 0 then
			vim.api.nvim_create_autocmd("VimEnter", {
				once = true,
				nested = true,
				callback = function()
					require("persistence").load()
				end,
			})
		end
	end,
	keys = {
		{
			"<leader>sr",
			function()
				require("persistence").load()
			end,
			desc = "Session: restore for cwd",
		},
		{
			"<leader>sR",
			function()
				require("persistence").select()
			end,
			desc = "Session: pick from list",
		},
		{
			"<leader>sL",
			function()
				require("persistence").load({ last = true })
			end,
			desc = "Session: restore last",
		},
		{
			"<leader>sd",
			function()
				require("persistence").stop()
			end,
			desc = "Session: stop saving",
		},
	},
}
