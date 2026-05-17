return {
	"kkoomen/vim-doge",
	keys = {
		{ "gDt", desc = "Doge Generate (default trigger)" },
		{ "gDc", "<Plug>(doge-generate)", desc = "Doge Generate" },
		{ "<TAB>", "<Plug>(doge-comment-jump-forward)", mode = { "n", "i", "x" } },
		{ "<S-TAB>", "<Plug>(doge-comment-jump-backward)", mode = { "n", "i", "x" } },
	},
	cmd = { "DogeGenerate", "DogeCreateDocStandard" },
	build = function()
		vim.fn["doge#install"]()
	end,
	init = function()
		vim.g.doge_enable_mappings = 0
		vim.g.doge_mapping = "gDt"
	end,
}
