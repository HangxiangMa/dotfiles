return {
	"SmiteshP/nvim-navic",
	enabled = false,
	dependencies = "neovim/nvim-lspconfig",
	opts = {
		lsp = {
			auto_attach = true,
			preference = nil,
		},
		highlight = true,
		lazy_update_context = false,
	}
}
