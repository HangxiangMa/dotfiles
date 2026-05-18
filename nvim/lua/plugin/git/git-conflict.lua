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
	opts = {
		default_mappings = true, -- co/ct/cb/c0 + ]x/[x
		default_commands = true,
		disable_diagnostics = false,
		list_opener = "copen",
		highlights = {
			incoming = "DiffAdd",
			current = "DiffText",
		},
	},
}
