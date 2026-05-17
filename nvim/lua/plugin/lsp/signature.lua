return {
	"ray-x/lsp_signature.nvim",
	event = {
		"BufWritePost",
		"BufReadPre",
		"BufNewFile",
	},
	opts = {
		bind = true, -- This is mandatory, otherwise border config won't get registered.
		handler_opts = {
			border = "rounded",
		},
	},
	config = function(_, opts)
		local lspsign = require("lsp_signature")
		lspsign.setup(opts)

		vim.keymap.set({ "n" }, "<leader>kt", function()
			lspsign.toggle_float_win()
		end, { silent = true, noremap = true, desc = "toggle signature" })
	end,
}
