-- Conflict markers as a first-class mode: pick ours/theirs/both/none, jump
-- between conflicts, list with :GitConflictListQf.
-- Loaded on real-file events so conflicts light up as soon as you open a file.
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
	config = function()
		require("git-conflict").setup({
			default_mappings = false,
			default_commands = true,
			disable_diagnostics = false,
			list_opener = "copen",
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		})

		-- Large-file guard. git-conflict installs a global decoration provider
		-- whose `on_win` re-scans a conflicted buffer end-to-end (4 regex/line)
		-- on every changedtick advance — fine for normal files, but on a 20k+
		-- line file in conflict that is an effectively per-keystroke full-buffer
		-- scan, and the plugin exposes no size cap. The provider gates each
		-- buffer through `utils.is_valid_buf(bufnr)` (returning false skips it
		-- entirely), so we wrap that to also reject oversized buffers. Small and
		-- mid-size files still light up automatically on open; only very large
		-- ones opt out of the live conflict decoration.
		local ok, utils = pcall(require, "git-conflict.utils")
		if ok and type(utils.is_valid_buf) == "function" then
			local MAX_CONFLICT_LINES = 12000
			local base_is_valid_buf = utils.is_valid_buf
			utils.is_valid_buf = function(bufnr)
				bufnr = bufnr or 0
				if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_line_count(bufnr) > MAX_CONFLICT_LINES then
					return false
				end
				return base_is_valid_buf(bufnr)
			end
		end
	end,
}
