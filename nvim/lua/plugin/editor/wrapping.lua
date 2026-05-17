return {
	"andrewferrier/wrapping.nvim",
	ft = { "asciidoc", "gitcommit", "mail", "markdown", "rst", "tex", "text" },
	keys = {
		{ "<leader>fRs", desc = "Soft Wrap Mode" },
		{ "<leader>fRh", desc = "Hard Wrap Mode" },
		{ "<leader>fRt", desc = "Toggle Wrap Mode" },
	},
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
}
