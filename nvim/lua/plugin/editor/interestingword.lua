return {
	"Mr-LLLLL/interestingwords.nvim",
	keys = {
		{ "<leader><leader>m", mode = { "n", "v" }, desc = "Search interesting word" },
		{ "<leader><leader>M", desc = "Cancel search" },
		{ "<leader><leader>k", mode = { "n", "v" }, desc = "Color interesting word" },
		{ "<leader><leader>K", desc = "Cancel colors" },
	},
	config = function()
		require("interestingwords").setup({
			colors = { "#e67e80", "#bfa3df", "#6cbbda", "#dfdb72", "#a4c5ea", "#9999ea", "#a7c080" },
			search_count = true,
			navigation = true,
			scroll_center = false,
			search_key = "<leader><leader>m",
			cancel_search_key = "<leader><leader>M",
			color_key = "<leader><leader>k",
			cancel_color_key = "<leader><leader>K",
			select_mode = "random", -- random or loop
		})
	end,
}
