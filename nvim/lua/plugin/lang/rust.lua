-- https://www.lazyvim.org/extras/lang/rust#rustaceanvim
return {
	{
		-- rustaceanvim has automatically configured the rust-analyzer
		-- builtin LSP client and integrates with other Rust tools.
		"mrcjkb/rustaceanvim",
		version = "^6", -- Recommended
		ft = { "rust" },
		opts = {
			server = {
				default_settings = {
					-- rust-analyzer language server configuration
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
							loadOutDirsFromCheck = true,
							buildScripts = {
								enable = true,
							},
						},
						-- Add clippy lints for Rust.
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
						inlayHints = {
							bindingModeHints = {
								enable = false,
							},
							chainingHints = {
								enable = true,
							},
							closingBraceHints = {
								enable = true,
								minLines = 25,
							},
							closureReturnTypeHints = {
								enable = "never",
							},
							lifetimeElisionHints = {
								enable = "never",
								useParameterNames = false,
							},
							maxLength = 25,
							parameterHints = {
								enable = true,
							},
							reborrowHints = {
								enable = "never",
							},
							renderColons = true,
							typeHints = {
								enable = true,
								hideClosureInitialization = false,
								hideNamedConstructor = false,
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			local crisp = require("core.crisp")
			vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
			if vim.fn.executable("rust-analyzer") == 0 then
				crisp.error(
					"**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
					"rustaceanvim"
				)
			end
		end,
	},
	{
		"Saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		config = function()
			local crates = require("crates")
			crates.setup()
			local function show_documentation()
				local filetype = vim.bo.filetype
				if vim.tbl_contains({ "vim", "help" }, filetype) then
					vim.cmd("h " .. vim.fn.expand("<cword>"))
				elseif vim.tbl_contains({ "man" }, filetype) then
					vim.cmd("Man " .. vim.fn.expand("<cword>"))
				elseif vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
					require("crates").show_popup()
				else
					vim.lsp.buf.hover()
				end
			end

			vim.keymap.set("n", "gh", show_documentation, { silent = true })
		end,
	},
}
