return {
	"andrewferrier/wrapping.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		softener = { markdown = true },
		-- set own mapping in 'which-key.lua'
		create_commands = false,
		create_keymaps = false,
		notify_on_switch = true,
		auto_set_mode_filetype_allowlist = {
			"asciidoc",
			"gitcommit",
			"mail",
			"markdown",
			"rst",
			"tex",
			"text",
		},
	},
	config = function(_, opts)
		require("wrapping").setup(opts)
	end,
}
