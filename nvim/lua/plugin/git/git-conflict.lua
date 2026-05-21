-- Conflict markers as a first-class mode: pick ours/theirs/both/none, jump
-- between conflicts, list with :GitConflictListQf.
-- Loaded on real-file events so non-git sessions stay light.
return {
	"akinsho/git-conflict.nvim",
	version = "*",
	event = { "BufReadPre", "BufNewFile" },
	cmd = {
		"GitConflictChooseOurs",
		"GitConflictChooseTheirs",
		"GitConflictChooseBoth",
		"GitConflictChooseNone",
		"GitConflictNextConflict",
		"GitConflictPrevConflict",
		"GitConflictListQf",
	},
	keys = {
		{ "<leader>gxo", "<cmd>GitConflictChooseOurs<cr>", desc = "Conflict: ours" },
		{ "<leader>gxt", "<cmd>GitConflictChooseTheirs<cr>", desc = "Conflict: theirs" },
		{ "<leader>gxb", "<cmd>GitConflictChooseBoth<cr>", desc = "Conflict: both" },
		{ "<leader>gx0", "<cmd>GitConflictChooseNone<cr>", desc = "Conflict: none" },
		{ "<leader>gxn", "<cmd>GitConflictNextConflict<cr>", desc = "Conflict: next" },
		{ "<leader>gxp", "<cmd>GitConflictPrevConflict<cr>", desc = "Conflict: prev" },
	},
	opts = {
		default_mappings = false,
		default_commands = true,
		disable_diagnostics = false,
		list_opener = "copen",
		highlights = {
			incoming = "DiffAdd",
			current = "DiffText",
		},
	},
}
