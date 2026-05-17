return {
	-- nvim-cmp
	{
		"hrsh7th/nvim-cmp",
		-- these dependencies will only be loaded when cmp loads
		-- dependencies are always lazy-loaded unless specified otherwise
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-calc",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			-- vsnip
			"hrsh7th/cmp-vsnip",
			"hrsh7th/vim-vsnip",
			-- luasnip
			{ "L3MON4D3/LuaSnip", version = "^v2", build = "make install_jsregexp" },
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
			"onsails/lspkind.nvim",
		},
		-- load cmp on InsertEnter and CmdlineEnter
		event = {
			"InsertEnter",
			"CmdlineEnter",
		},
		config = function()
			local cmp = require("cmp")
			local lspkind = require("lspkind")
			local select_opts = { behavior = cmp.SelectBehavior.Select }
			local status_ok, luasnip = pcall(require, "luasnip")
			cmp.setup({
				experimental = {
					ghost_text = true,
				},
				snippet = {
					-- REQUIRED - you must specify a snippet engine
					expand = function(args)
						vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users
						-- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
					end,
				},

				window = {
					completion = {
						border = "rounded",
					},
					documentation = {
						border = "rounded",
					},
				},

				mapping = {
					-- select previous one
					["<C-p>"] = cmp.mapping.select_prev_item(),
					-- select next one
					["<C-n>"] = cmp.mapping.select_next_item(),
					-- show auto complete
					["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
					-- cancel auto complete
					["<C-e>"] = cmp.mapping({
						i = cmp.mapping.abort(),
						c = cmp.mapping.close(),
					}),

					-- select
					["<CR>"] = cmp.mapping.confirm({
						select = true,
						behavior = cmp.ConfirmBehavior.Replace,
					}),

					-- scroll up
					["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
					-- scroll down
					["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),

					-- solve placeholder movement problem
					-- <https://vonheikemen.github.io/devlog/tools/setup-nvim-lspconfig-plus-nvim-cmp/>
					["<Tab>"] = cmp.mapping(function(fallback)
						local col = vim.fn.col(".") - 1

						if cmp.visible() then
							cmp.select_next_item(select_opts)
						elseif col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
							fallback()
						elseif status_ok and luasnip.expand_or_locally_jumpable() then
							luasnip.expand_or_jump()
						else
							cmp.complete()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item(select_opts)
						elseif status_ok and luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				},

				sources = cmp.config.sources({
					{ name = "jupyter" },
					{ name = "treesitter" },
					{ name = "path" },
					{ name = "nvim_lsp", keyword_length = 1 },
					{ name = "buffer", keyword_length = 3 },
					{ name = "luasnip", keyword_length = 2 },
					{ name = "vsnip" },
					{ name = "calc" },
					{ name = "crates" },
					{
						name = "lazydev",
						group_index = 0, -- set group index to 0 to skip loading LuaLS completions
					},
				}),

				-- according filetype to select sources
				cmp.setup.filetype("gitcommit", {
					sources = cmp.config.sources({
						{ name = "buffer" },
					}),
				}),

				-- use '/' to trigger auto complete under command mode
				cmp.setup.cmdline("/", {
					mapping = cmp.mapping.preset.cmdline(),
					sources = {
						{ name = "buffer" },
					},
				}),

				-- use ':' to trigger auto complete under command mode
				cmp.setup.cmdline(":", {
					mapping = cmp.mapping.preset.cmdline(),
					sources = cmp.config.sources({
						{ name = "path" },
					}, {
						{ name = "cmdline" },
					}),
				}),

				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						--mode = 'symbol', -- show only symbol annotations

						maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
						-- The function below will be called before any actual modifications from lspkind
						-- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
						before = function(entry, vim_item)
							vim_item.menu = "[" .. string.upper(entry.source.name) .. "]"
							return vim_item
						end,
					}),
				},
			})
		end,
	},
}
