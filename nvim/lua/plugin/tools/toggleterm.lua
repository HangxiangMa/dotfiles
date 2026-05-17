return {
	"akinsho/toggleterm.nvim",
	version = "*", -- Terminal
	event = "VeryLazy",
	config = function()
		require("toggleterm").setup({
			size = function(term)
				if term.direction == "horizontal" then
					return 15
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.3
				end
			end,
			open_mapping = [[<c-\>]], -- or { [[<c-\>]], [[<c-¥>]] } if you also use a Japanese keyboard.
			hide_numbers = true, -- hide the number column in toggleterm buffers
			shade_filetypes = {},
			autochdir = false, -- when neovim changes it current directory the terminal will change it's own when next it's opened
			shade_terminals = true, -- NOTE: this option takes priority over highlights specified so if you specify Normal highlights you should set this to false
			shading_factor = 2, -- the percentage by which to lighten terminal background, default: -30 (gets multiplied by -3 if background is light)
			start_in_insert = true, -- start with insert mode
			insert_mappings = true, -- whether or not the open mapping applies in insert mode
			persist_size = true,
			persist_mode = true, -- if set to true (default) the previous terminal mode will be remembered
			direction = "float",
			close_on_exit = true, -- close the terminal window when the process exits
			-- Change the default shell. Can be a string or a function returning a string
			shell = vim.o.shell,
			auto_scroll = true, -- automatically scroll to the bottom on terminal output
			-- This field is only relevant if direction is set to 'float'
			float_opts = {
				-- The border key is *almost* the same as 'nvim_open_win'
				-- see :h nvim_open_win for details on borders however
				-- the 'curved' border is a custom border type
				-- not natively supported but implemented in this plugin.
				border = "curved",
				-- like `size`, width and height can be a number or function which is passed the current terminal
				winblend = 0,
				highlights = {
					border = "Normal",
					background = "Normal",
				},
			},
		})

		function _G.set_terminal_keymaps()
			local opts = { noremap = true, buffer = 0 }
			vim.keymap.set("n", "<C-q>", "<cmd>close<CR>", opts)
			vim.keymap.set("t", "<C-q>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "<C-h>", [[<cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end

		-- if you only want these mappings for toggle term use term://*toggleterm#* instead
		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

		local Terminal = require("toggleterm.terminal").Terminal

		-- lazygit
		local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
		function _LAZYGIT_TOGGLE()
			lazygit:toggle()
		end
		vim.api.nvim_set_keymap("n", "<leader>tg", "<cmd>lua _LAZYGIT_TOGGLE()<CR>", { noremap = true, silent = true })

		-- ncdu
		local ncdu = Terminal:new({ cmd = "ncdu", hidden = true })
		function _NCDU_TOGGLE()
			ncdu:toggle()
		end
		vim.api.nvim_set_keymap("n", "<leader>tn", "<cmd>lua _NCDU_TOGGLE()<CR>", { noremap = true, silent = true })

		-- htop
		local htop = Terminal:new({ cmd = "htop", hidden = true })
		function _HTOP_TOGGLE()
			htop:toggle()
		end
		vim.api.nvim_set_keymap("n", "<leader>tt", "<cmd>lua _HTOP_TOGGLE()<CR>", { noremap = true, silent = true })

		local M = {}
		local ta = Terminal:new({
			direction = "float",
			close_on_exit = true,
		})
		local tb = Terminal:new({
			direction = "vertical",
			close_on_exit = true,
		})
		local tc = Terminal:new({
			direction = "horizontal",
			close_on_exit = true,
		})
		-- float
		M.toggleFloat = function()
			if ta:is_open() then
				ta:close()
				return
			end
			tb:close()
			tc:close()
			ta:open()
		end
		-- vertical
		M.toggleVertical = function()
			if tb:is_open() then
				tb:close()
				return
			end
			ta:close()
			tc:close()
			tb:open()
		end
		-- horizontal
		M.toggleHorizontal = function()
			if tc:is_open() then
				tc:close()
				return
			end
			ta:close()
			tb:close()
			tc:open()
		end
		vim.keymap.set("n", "<leader>tf", M.toggleFloat, { silent = true, desc = "Terminal Float" })
		vim.keymap.set("n", "<leader>tv", M.toggleVertical, { silent = true, desc = "Terminal Vertical" })
		vim.keymap.set("n", "<leader>th", M.toggleHorizontal, { silent = true, desc = "Terminal Horizontal" })
	end,
}
