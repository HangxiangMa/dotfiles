return {
	"Mr-LLLLL/interestingwords.nvim",
	keys = {
		{ "<leader><leader>m", mode = { "n", "v" }, desc = "Search interesting word" },
		{ "<leader><leader>M", desc = "Cancel search" },
		{ "<leader><leader>k", mode = { "n", "v" }, desc = "Color interesting word" },
		{ "<leader><leader>K", desc = "Cancel colors" },
	},
	config = function()
		-- search_count / navigation are the ONLY code paths that join the whole
		-- buffer into one string on every trigger: `search_count` re-joins the
		-- buffer + matchstrpos-scans it after each `/`?`; `navigation` remaps
		-- n/N to a jump that joins the buffer TWICE per keypress. On a 20k-line
		-- file that turns the most common navigation keys into a per-keystroke
		-- full-buffer scan. Both are off here — the core highlight (matchadd,
		-- viewport-recomputed) and the <leader><leader>m/k search+color keys are
		-- unaffected; only the built-in count readout and n/N takeover are lost.
		require("interestingwords").setup({
			colors = { "#e67e80", "#bfa3df", "#6cbbda", "#dfdb72", "#a4c5ea", "#9999ea", "#a7c080" },
			search_count = false,
			navigation = false,
			scroll_center = false,
			search_key = "<leader><leader>m",
			cancel_search_key = "<leader><leader>M",
			color_key = "<leader><leader>k",
			cancel_color_key = "<leader><leader>K",
			select_mode = "random", -- random or loop
		})
	end,
}
