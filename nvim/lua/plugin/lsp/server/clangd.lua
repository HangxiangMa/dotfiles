local server = {}

require("lib.inactive_regions").setup()

function server.checkOK()
	return vim.fn.executable("clangd") == 1
end

function server.setup()
	vim.lsp.config("clangd", {
		capabilities = {
			offsetEncoding = { "utf-8", "utf-16" },
			textDocument = {
				completion = { editsNearCursor = true },
				inactiveRegionsCapabilities = { inactiveRegions = true },
			},
		},
	})
	vim.lsp.enable("clangd")
end

return server
