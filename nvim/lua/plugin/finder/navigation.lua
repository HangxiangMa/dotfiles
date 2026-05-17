return {
	-- nvim tree
	{
		"nvim-tree/nvim-tree.lua",
		version = "^v1",
		cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile", "NvimTreeOpen" },
		keys = {
			{ "<C-B>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle Explorer" },
		},
		-- Eagerly load when nvim was launched on a directory (e.g. `nvim .`)
		-- so it can take over from netrw. Otherwise it stays lazy.
		lazy = (function()
			local argv = vim.fn.argv()
			if #argv ~= 1 then
				return true
			end
			local stat = (vim.uv or vim.loop).fs_stat(argv[1])
			return not (stat and stat.type == "directory")
		end)(),
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				sort = {
					sorter = "case_sensitive",
				},
				view = {
					width = 40,
				},
				update_focused_file = {
					enable = true,
					update_root = { enable = false },
				},
				-- Replace netrw's "open the directory in a buffer" behaviour
				-- so `nvim <folder>` opens nvim-tree on that folder.
				hijack_directories = {
					enable = true,
					auto_open = true,
				},
				renderer = { group_empty = true },
				filters = { dotfiles = true },
			})

			local api = require("nvim-tree.api")
			vim.keymap.set("n", "g?", api.tree.toggle_help, {
				desc = "nvim-tree: Help",
				noremap = true,
				silent = true,
				nowait = true,
			})
		end,
	},
	-- tmux
	{
		"christoomey/vim-tmux-navigator",
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
			"TmuxNavigatorProcessList",
		},
		keys = {
			{ "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
			{ "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
			{ "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
			{ "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
			{ "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
		},
	},
}
