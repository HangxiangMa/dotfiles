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
		-- jump between buffers
		-- config below keymaps in `which-key.lua`
		-- <leader>1 to 9

		-- switch to next/previous buffer
		vim.api.nvim_set_keymap("n", "<leader>tj", ":BufferLineCycleNext<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>tk", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true })
		-- select a specific tab
		vim.api.nvim_set_keymap("n", "<leader>tp", ":BufferLinePick<CR>", { noremap = true, silent = true })
		-- close current buffer
		vim.api.nvim_set_keymap("n", "<leader>td", ":bdelete %<CR>", { noremap = true, silent = true })
		-- select one buffer and close it
		vim.api.nvim_set_keymap("n", "<leader>tcp", ":BufferLinePickClose<CR>", { noremap = true, silent = true })
		-- close all buffer other than current one
		vim.api.nvim_set_keymap(
			"n",
			"<leader>tco",
			":BufferLineCloseLeft<CR>:BufferLineCloseRight<CR>",
			{ noremap = true, silent = true }
		)
		-- close left/right buffer
		vim.api.nvim_set_keymap("n", "<leader>tcl", ":BufferLineCloseLeft<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>tcr", ":BufferLineCloseRight<CR>", { noremap = true, silent = true })
	end,
}
