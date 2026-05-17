local server = {}

function server.checkOK()
	return vim.fn.executable("rust-analyzer") == 1
end

function server.setup()
	vim.lsp.config("rust_analyzer", {
		filetypes = { "rust" },
		settings = {
			["rust-analyzer"] = {
				diagnostics = { enable = true },
				completion = {
					autoimport = { enable = true },
					postfix = { enable = true },
				},
				cargo = {
					allFeatures = true,
					loadOutDirsFromCheck = true,
					buildScripts = { enable = true },
				},
				checkOnSave = {
					allFeatures = true,
					command = "clippy",
					extraArgs = { "--no-deps" },
				},
				procMacro = {
					enable = true,
					ignored = {
						["async-trait"] = { "async_trait" },
						["napi-derive"] = { "napi" },
						["async-recursion"] = { "async_recursion" },
					},
				},
			},
		},
	})
	vim.lsp.enable("rust_analyzer")
end

return server
