return {
	"folke/ts-comments.nvim",
	opts = {},
	event = { "BufReadPre" },
	-- FIXME: Update this after nvim upgrared
	enabled = vim.fn.has("nvim-0.10.0") == 1,
}
