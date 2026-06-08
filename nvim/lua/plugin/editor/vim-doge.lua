return {
	"kkoomen/vim-doge",
	keys = {
		{ "gDt", desc = "Doge Generate (default trigger)" },
		{ "gDc", "<Plug>(doge-generate)", desc = "Doge Generate" },
		-- Insert-mode <Tab> belongs to blink.cmp (completion / snippet jump).
		-- Declaring it here makes lazy.nvim install an insert-mode <Tab>
		-- lazy-load stub that shadows blink and freezes insert mode, so keep
		-- doge's placeholder jumps on normal/visual only.
		{ "<TAB>", "<Plug>(doge-comment-jump-forward)", mode = { "n", "x" } },
		{ "<S-TAB>", "<Plug>(doge-comment-jump-backward)", mode = { "n", "x" } },
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
