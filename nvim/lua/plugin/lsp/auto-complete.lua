-- Completion engine: blink.cmp (Rust-backed fuzzy matcher).
-- Replaces the previous nvim-cmp + vsnip + cmp-* stack. LuaSnip is kept as
-- the snippet engine; lspkind is no longer required because blink.cmp ships
-- its own kind icons.
return {
	{
		"saghen/blink.cmp",
		event = { "InsertEnter", "CmdlineEnter" },
		-- Use a tagged release so the prebuilt fuzzy binary is downloaded
		-- (no Rust toolchain needed). Pin to v1.* for stability.
		version = "v1.*",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				version = "^v2",
				build = "make install_jsregexp",
				dependencies = { "rafamadriz/friendly-snippets" },
				config = function()
					require("luasnip.loaders.from_vscode").lazy_load()
				end,
			},
		},
		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = {
				preset = "default",
				-- Mirror the previous nvim-cmp keymap so muscle memory survives.
				["<C-n>"] = { "select_next", "fallback" },
				["<C-p>"] = { "select_prev", "fallback" },
				["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-e>"] = { "hide", "fallback" },
				["<CR>"] = { "accept", "fallback" },
				["<C-u>"] = { "scroll_documentation_up", "fallback" },
				["<C-d>"] = { "scroll_documentation_down", "fallback" },
				["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
				["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
			},
			snippets = { preset = "luasnip" },
			appearance = {
				use_nvim_cmp_as_default = false,
				nerd_font_variant = "mono",
			},
			completion = {
				accept = { auto_brackets = { enabled = true } },
				menu = {
					border = "rounded",
					draw = {
						treesitter = { "lsp" },
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
							{ "source_name" },
						},
					},
				},
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					window = { border = "rounded" },
				},
				ghost_text = { enabled = true },
				list = { selection = { preselect = true, auto_insert = false } },
			},
			signature = {
				enabled = true,
				window = { border = "rounded" },
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "lazydev" },
				per_filetype = {
					-- crates.nvim ships its own blink integration via Saecki/crates.nvim's
					-- `completion.cmp.use_custom_kind_highlight` path; we just keep the
					-- LSP source here, the popup itself is enough for Cargo.toml work.
					rust = { "lsp", "path", "snippets", "buffer" },
				},
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100,
					},
					buffer = {
						-- 3-char prefilter: matches the previous nvim-cmp keyword_length=3.
						min_keyword_length = 3,
						max_items = 5,
					},
					snippets = { min_keyword_length = 2 },
				},
			},
			cmdline = {
				keymap = {
					preset = "cmdline",
					["<Tab>"] = { "show_and_insert", "select_next" },
					["<S-Tab>"] = { "show_and_insert", "select_prev" },
					["<CR>"] = { "accept_and_enter", "fallback" },
				},
				completion = {
					list = { selection = { preselect = false } },
					menu = { auto_show = true },
					ghost_text = { enabled = true },
				},
			},
			-- Use the new Rust-backed fuzzy matcher. Falls back to lua matcher if
			-- the prebuilt binary isn't available for the current platform.
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
}
