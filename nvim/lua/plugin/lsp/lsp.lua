-- Single source of truth for LSP servers.
-- Each entry maps a lspconfig server name to:
--   mason     - the mason package name (omit if not installed via mason)
--   exe       - executable to probe with vim.fn.executable() before enabling
--   custom    - module under plugin.lsp.server.* that does its own setup
--               (e.g. clangd, rust). When set, we never call vim.lsp.enable here.
local SERVERS = {
	bashls   = { mason = "bash-language-server",  exe = "bash-language-server" },
	clangd   = { mason = "clangd",                exe = "clangd",               custom = "clangd" },
	cmake    = { mason = "cmake-language-server", exe = "cmake-language-server" },
	lua_ls   = { mason = "lua-language-server",   exe = "lua-language-server" },
	marksman = { mason = "marksman",              exe = "marksman" },
	pyright  = { mason = "pyright",               exe = "pyright" },
	rust_analyzer = { exe = "rust-analyzer", custom = "rust" }, -- installed via rustup, not mason
	taplo    = { mason = "taplo",                 exe = "taplo" },
}

-- Extra (non-server) tools mason should install for formatters/linters.
local MASON_TOOLS = {
	"black",
	"clang-format",
	"cmakelang",
	"codelldb",
	"luaformatter",
	"prettier",
	"shfmt",
}

local function mason_ensure_installed()
	local list = vim.deepcopy(MASON_TOOLS)
	for _, cfg in pairs(SERVERS) do
		if cfg.mason then
			table.insert(list, cfg.mason)
		end
	end
	return list
end

local function mason_lspconfig_ensure()
	local list = {}
	for name, cfg in pairs(SERVERS) do
		if cfg.mason then
			table.insert(list, name)
		end
	end
	return list
end

return {
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		event = "VeryLazy",
		opts = {
			ui = {
				icons = {
					package_installed = "√",
					package_pending = "→",
					package_uninstalled = "×",
				},
			},
			ensure_installed = mason_ensure_installed(),
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			mr:on("package:install:success", function()
				vim.defer_fn(function()
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)
			local function ensure_installed()
				for _, tool in ipairs(opts.ensure_installed) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						p:install()
					end
				end
			end
			if mr.refresh then
				mr.refresh(ensure_installed)
			else
				ensure_installed()
			end
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		event = "VeryLazy",
		dependencies = "williamboman/mason.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = mason_lspconfig_ensure(),
				automatic_installation = true,
			})
		end,
	},

	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
			"windwp/nvim-autopairs",
		},
		config = function()
			require("lspconfig.ui.windows").default_options = { border = "rounded" }

			-- Diagnostic UI. Sign text/highlights are configured via
			-- `vim.diagnostic.config({ signs = { text = ..., numhl = ... } })`
			-- on Neovim 0.10+; the older `sign_define("DiagnosticSign*", ...)`
			-- API is deprecated.
			vim.diagnostic.config({
				virtual_text = false,
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN]  = "󰀪 ",
						[vim.diagnostic.severity.HINT]  = "󰌶 ",
						[vim.diagnostic.severity.INFO]  = " ",
					},
					numhl = {
						[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
						[vim.diagnostic.severity.WARN]  = "DiagnosticSignWarn",
						[vim.diagnostic.severity.HINT]  = "DiagnosticSignHint",
						[vim.diagnostic.severity.INFO]  = "DiagnosticSignInfo",
					},
				},
				underline = true,
				severity_sort = true,
				update_in_insert = false,
				float = {
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			})

			-- Default capabilities for every server (cmp + folding range for ufo).
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
			if ok_cmp then
				capabilities = cmp_lsp.default_capabilities(capabilities)
			end
			capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}
			vim.lsp.config("*", { capabilities = capabilities })

			-- LspAttach: shared per-buffer behaviour (codelens refresh, document
			-- highlight, formatting opt-out for noisy servers).
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					if not client then return end

					if client.name == "tsserver" or client.name == "rust_analyzer" then
						client.server_capabilities.documentFormattingProvider = false
					end

					if client.server_capabilities.documentHighlightProvider then
						local hl_group = vim.api.nvim_create_augroup(
							"user_lsp_doc_highlight_" .. ev.buf, { clear = true }
						)
						vim.api.nvim_create_autocmd("CursorHold", {
							group = hl_group, buffer = ev.buf,
							callback = vim.lsp.buf.document_highlight,
						})
						vim.api.nvim_create_autocmd("CursorMoved", {
							group = hl_group, buffer = ev.buf,
							callback = vim.lsp.buf.clear_references,
						})
					end

					local ok, supported = pcall(client.supports_method, "textDocument/codeLens")
					if ok and supported then
						local cl_group = vim.api.nvim_create_augroup(
							"user_lsp_codelens_" .. ev.buf, { clear = false }
						)
						vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
							group = cl_group, buffer = ev.buf,
							callback = function()
								if vim.api.nvim_buf_is_loaded(ev.buf) and vim.api.nvim_buf_is_valid(ev.buf) then
									vim.lsp.codelens.refresh({ bufnr = ev.buf })
								end
							end,
						})
					end
				end,
			})

			local crisp = require("core.crisp")
			for name, cfg in pairs(SERVERS) do
				if vim.fn.executable(cfg.exe) ~= 1 then
					if crisp.notifyLSPError() then
						crisp.warn("LSP server '" .. name .. "' (exe: " .. cfg.exe .. ") not found", "LSP")
					end
				elseif cfg.custom then
					local mod = crisp.prequire("plugin.lsp.server." .. cfg.custom)
					if mod and mod.setup then
						mod.setup()
					end
				else
					vim.lsp.enable(name)
				end
			end
		end,
	},

	{
		"jinzhongjia/LspUI.nvim",
		event = "VeryLazy",
		branch = "main",
		opts = {
			code_action = { keys = { quit = "q", prev = "k", next = "j", exec = "<CR>" } },
			hover       = { keys = { prev = "k", next = "j", exec = "<CR>" } },
		},
	},
}
