-- Project-wide find/replace with preview window.
-- Lazy-loaded purely on cmd/keys to keep startup costs at zero.
return {
	"MagicDuck/grug-far.nvim",
	cmd = { "GrugFar", "GrugFarWithin" },
	keys = {
		{
			"<leader>rr",
			function()
				require("grug-far").open()
			end,
			desc = "Find and Replace (Project)",
		},
		{
			"<leader>rw",
			function()
				require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
			end,
			desc = "Find and Replace (cword)",
		},
		{
			"<leader>rb",
			function()
				require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
			end,
			desc = "Find and Replace (Buffer)",
		},
		{
			"<leader>r",
			mode = "v",
			function()
				require("grug-far").with_visual_selection()
			end,
			desc = "Find and Replace (Visual)",
		},
	},
	opts = {
		headerMaxWidth = 80,
	},
}
