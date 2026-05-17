---@type LazySpec
return {
	"mikavilpas/yazi.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	event = "VeryLazy",
	keys = {
		{
			-- 👇 choose your own keymapping
			"<leader>-",
			function()
				require("yazi").yazi()
			end,
			{ desc = "Open the file manager" },
		},
	},
	---@type YaziConfig
	opts = {
		open_for_directories = false,
	},
}
