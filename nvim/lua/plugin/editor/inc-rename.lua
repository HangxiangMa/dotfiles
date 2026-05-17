return {
	"smjonas/inc-rename.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("inc_rename").setup({})
		vim.keymap.set("n", "gR", ":IncRename ")
	end,
}
