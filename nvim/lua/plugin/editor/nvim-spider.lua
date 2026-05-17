return {
	"chrisgrieser/nvim-spider",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		vim.keymap.set(
			{ "n", "o", "x" },
			"<leader>w",
			"<cmd>lua require('spider').motion('w')<CR>",
			{ desc = "Spider-w", noremap = true }
		)
		vim.keymap.set(
			{ "n", "o", "x" },
			"<leader>e",
			"<cmd>lua require('spider').motion('e')<CR>",
			{ desc = "Spider-e", noremap = true }
		)
		vim.keymap.set(
			{ "n", "o", "x" },
			"<leader>b",
			"<cmd>lua require('spider').motion('b')<CR>",
			{ desc = "Spider-b", noremap = true }
		)
	end,
}
