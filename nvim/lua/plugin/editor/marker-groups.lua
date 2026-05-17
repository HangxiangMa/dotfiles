return {
	"jameswolensky/marker-groups.nvim",
	keys = {
		{ "<leader>Ma", mode = { "n", "v" }, desc = "Add marker" },
		{ "<leader>Me", desc = "Edit marker at cursor" },
		{ "<leader>Md", desc = "Delete marker at cursor" },
		{ "<leader>Ml", desc = "List markers in buffer" },
		{ "<leader>Mi", desc = "Show marker at cursor" },
		{ "<leader>Mv", desc = "Toggle drawer marker viewer" },
		{ "<leader>Mgc", desc = "Create marker group" },
		{ "<leader>Mgs", desc = "Select marker group" },
		{ "<leader>Mgl", desc = "List marker groups" },
		{ "<leader>Mgr", desc = "Rename marker group" },
		{ "<leader>Mgd", desc = "Delete marker group" },
		{ "<leader>Mgi", desc = "Show active group info" },
		{ "<leader>Mgb", desc = "Create group from git branch" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required
		"ibhagwan/fzf-lua", -- Optional: fzf-lua picker
		"folke/snacks.nvim", -- Active picker (see opts.picker below)
	},
	config = function()
		require("marker-groups").setup({
			-- Keybindings (declarative; override per entry or disable by setting to false)
			keymaps = {
				enabled = true,
				prefix = "<leader>M",
				mappings = {
					marker = {
						add = { suffix = "a", mode = { "n", "v" }, desc = "Add marker" },
						edit = { suffix = "e", desc = "Edit marker at cursor" },
						delete = { suffix = "d", desc = "Delete marker at cursor" },
						list = { suffix = "l", desc = "List markers in buffer" },
						info = { suffix = "i", desc = "Show marker at cursor" },
					},
					group = {
						create = { suffix = "gc", desc = "Create marker group" },
						select = { suffix = "gs", desc = "Select marker group" },
						list = { suffix = "gl", desc = "List marker groups" },
						rename = { suffix = "gr", desc = "Rename marker group" },
						delete = { suffix = "gd", desc = "Delete marker group" },
						info = { suffix = "gi", desc = "Show active group info" },
						from_branch = { suffix = "gb", desc = "Create group from git branch" },
					},
					view = { toggle = { suffix = "v", desc = "Toggle drawer marker viewer" } },
				},
			},
			-- Default picker is 'vim' (built-in vim.ui)
			-- Accepted values: 'vim' | 'snacks' | 'fzf-lua' | 'mini.pick' | 'telescope'
			picker = "snacks",
		})
	end,
}
