-- Clipboard ring + smart paste with highlight.
-- Lazy-loaded on its keys so TextYankPost autocmd is only attached on first use.
return {
	"gbprod/yanky.nvim",
	keys = {
		{
			"<leader>yp",
			function()
				require("yanky.picker").pick({ picker = "fzf-lua" })
			end,
			desc = "Yank History",
		},
		{ "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
		{ "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put after" },
		{ "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put before" },
		{ "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" }, desc = "Put after (cursor)" },
		{ "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" }, desc = "Put before (cursor)" },
		{ "<c-n>", "<Plug>(YankyCycleForward)", desc = "Cycle yank forward" },
		{ "<c-p>", "<Plug>(YankyCycleBackward)", desc = "Cycle yank backward" },
		{ "]p", "<Plug>(YankyPutIndentAfterLinewise)", desc = "Put indented after (linewise)" },
		{ "[p", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "Put indented before (linewise)" },
	},
	opts = {
		ring = {
			history_length = 100,
			storage = "shada",
			sync_with_numbered_registers = true,
			cancel_event = "update",
		},
		picker = {
			select = { action = nil },
		},
		highlight = {
			on_put = true,
			on_yank = true,
			timer = 200,
		},
		preserve_cursor_position = { enabled = true },
		textobj = { enabled = true },
	},
}
