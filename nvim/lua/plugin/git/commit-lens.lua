-- commit-lens: a repo-local plugin (nvim/plugins/commit-lens) that marks the
-- lines of the current code belonging to a chosen set of commits, via git
-- blame, as an independent highlight layer that coexists with gitsigns.
--
-- Loaded lazily on its commands / nav keys. See the plugin's init.lua for the
-- rationale and the known limitation (pure-deletion commits have no surviving
-- line to mark — use :DiffviewFileHistory for those).
return {
	"commit-lens",
	dir = vim.fn.stdpath("config") .. "/plugins/commit-lens",
	cmd = { "CommitLens", "CommitLensClear", "CommitLensFiles" },
	keys = {
		{ "]h", desc = "Next commit-lens line" },
		{ "[h", desc = "Prev commit-lens line" },
	},
	config = function()
		require("commit-lens").setup()
	end,
}
