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
		-- Buffer/Tab navigation lives under <leader>B*; numbered jumps
		-- (<leader>B1..5) and the arena toggle (<leader>Bm) are declared in
		-- which-key.lua. Lowercase <leader>b is reserved for nvim-spider's
		-- backward word motion, and <leader>t* is reserved for terminals.
		local map = function(lhs, rhs)
			vim.api.nvim_set_keymap("n", lhs, rhs, { noremap = true, silent = true })
		end
		map("<leader>Bn", ":BufferLineCycleNext<CR>")
		map("<leader>Bp", ":BufferLineCyclePrev<CR>")
		map("<leader>BP", ":BufferLinePick<CR>")
		map("<leader>Bd", ":bdelete %<CR>")
		map("<leader>Bcp", ":BufferLinePickClose<CR>")
		map("<leader>Bco", ":BufferLineCloseLeft<CR>:BufferLineCloseRight<CR>")
		map("<leader>Bcl", ":BufferLineCloseLeft<CR>")
		map("<leader>Bcr", ":BufferLineCloseRight<CR>")
	end,
}
