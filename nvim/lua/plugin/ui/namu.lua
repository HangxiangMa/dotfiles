return {
	"bassamsdata/namu.nvim",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("namu").setup({
			-- Enable the modules you want
			namu_symbols = {
				enable = true,
				options = {
					window = {
						height_ratio = 0.6,
						max_height = 30, -- Sets the maximum height
					},
					row_position = "top10_right",
					-- in namu_symbols.options
					movement = {
						next = { "<C-n>", "<DOWN>" }, -- Support multiple keys
						previous = { "<C-p>", "<UP>" }, -- Support multiple keys
						close = { "<ESC>" }, -- close mapping
						select = { "<CR>" }, -- select mapping
						delete_word = {}, -- delete word mapping
						clear_line = {}, -- clear line mapping
					},
					multiselect = {
						enabled = false,
						indicator = "●", -- or "✓"◉
						keymaps = {
							toggle = "<Tab>",
							select_all = "<C-a>",
							clear_all = "<C-l>",
							untoggle = "<S-Tab>",
						},
						max_items = nil, -- No limit by default
					},
					custom_keymaps = {
						yank = {
							keys = { "<C-y>" }, -- yank symbol text
						},
						delete = {
							keys = { "<C-d>" }, -- delete symbol text
						},
						vertical_split = {
							keys = { "<C-v>" }, -- open in vertical split
						},
						horizontal_split = {
							keys = { "<C-h>" }, -- open in horizontal split
						},
						codecompanion = {
							keys = "<C-o>", -- Add symbols to CodeCompanion
						},
						avante = {
							keys = "<C-t>", -- Add symbol to Avante
						},
					},
					-- Suggestion Reference: https://github.com/bassamsdata/namu.nvim/issues/28
					current_highlight = {
						enabled = true, -- Enable custom prefix icon
						hl_group = "PmenuSel", -- Default highlight group: Visual. CursorLine, PmenuSel are also available
						-- Please keep space after the icon for better viewing
						prefix_icon = " ", --icon for current selection, some other example ▎ 󰇙 ┆
					},
				}, -- here you can configure namu
			},
			-- Optional: Enable other modules if needed
			ui_select = { enable = false }, -- vim.ui.select() wrapper
			colorscheme = {
				enable = false,
				options = {
					-- NOTE: if you activate persist, then please remove any vim.cmd("colorscheme ...") in your config, no needed anymore
					persist = true, -- very efficient mechanism to Remember selected colorscheme
					write_shada = false, -- If you open multiple nvim instances, then probably you need to enable this
				},
			},
		})
		-- FIXME: Similar to the Visual group in OneDark
		vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2d323b" }) -- darker than onedark palette bg2
		-- === Suggested Keymaps: ===
		vim.keymap.set("n", "<leader>ks", ":Namu symbols<cr>", {
			desc = "Jump to LSP symbol",
			silent = true,
		})
	end,
}
