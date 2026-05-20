local server = {}

require("lib.inactive_regions").setup()

function server.checkOK()
	return vim.fn.executable("clangd") == 1
end

function server.setup()
	vim.lsp.config("clangd", {
		cmd = {
			"clangd",
			"--background-index",
			"--clang-tidy",
			"--completion-style=detailed",
			"--header-insertion=iwyu",
			"--header-insertion-decorators",
			"--all-scopes-completion",
			"--function-arg-placeholders",
			"--pch-storage=memory",
			"--fallback-style=llvm",
			"--enable-config",
			"--query-driver=**",
			"-j=8",
		},
		capabilities = {
			offsetEncoding = { "utf-8", "utf-16" },
			textDocument = {
				completion = { editsNearCursor = true },
				inactiveRegionsCapabilities = { inactiveRegions = true },
			},
		},
		-- Used when no compile_commands.json is found in the project tree.
		-- Without these clangd builds an empty AST and emits "invalid AST"
		-- for every semantic-tokens / inactiveRegions request.
		init_options = {
			fallbackFlags = {
				"-std=gnu11",
				"-Wall",
				"-Wextra",
				"-Wno-unused-parameter",
				"-Wno-unused-function",
				"-Wno-unused-variable",
				"-Wno-unused-but-set-variable",
				"-Wno-missing-field-initializers",
				"-Wno-unknown-pragmas",
				"-Wno-implicit-function-declaration",
				"-Wno-implicit-fallthrough",
				"-Wno-gnu-zero-variadic-macro-arguments",
				"-ferror-limit=0",
				"-fno-builtin",
				"-D_GNU_SOURCE",
			},
		},
	})
	vim.lsp.enable("clangd")
end

return server
