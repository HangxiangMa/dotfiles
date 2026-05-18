return {
	"akinsho/bufferline.nvim",
	version = "^v4",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons", lazy = true },
	config = function()
		require("bufferline").setup({
			options = {
				mode = "buffers",
				number = "ordinal", -- show id
				themable = true,
				diagnostics = "nvim_lsp", -- use internal lsp
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						highlight = "Directory",
						text_align = "left",
					},
				},
				indicator = {
					icon = "▎", -- this should be omitted if indicator style is not 'icon'
					style = "icon",
				},
				always_show_bufferline = false,
			},
		})
		-- Buffer/Tab navigation lives under <leader>t*; numbered jumps
		-- (<leader>t1..5) and the arena toggle (<leader>tm) are declared
		-- in which-key.lua. Terminal toggles use <leader>T*.
		local map = function(lhs, rhs)
			vim.api.nvim_set_keymap("n", lhs, rhs, { noremap = true, silent = true })
		end
		map("<leader>tn", ":BufferLineCycleNext<CR>")
		map("<leader>tp", ":BufferLineCyclePrev<CR>")
		map("<leader>tP", ":BufferLinePick<CR>")
		map("<leader>td", ":bdelete %<CR>")
		map("<leader>tcp", ":BufferLinePickClose<CR>")
		map("<leader>tco", ":BufferLineCloseLeft<CR>:BufferLineCloseRight<CR>")
		map("<leader>tcl", ":BufferLineCloseLeft<CR>")
		map("<leader>tcr", ":BufferLineCloseRight<CR>")
	end,
}
