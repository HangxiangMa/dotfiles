return {
	"andrewferrier/wrapping.nvim",
	ft = { "asciidoc", "gitcommit", "mail", "markdown", "rst", "tex", "text" },
	-- Keymaps live in which-key.lua under <leader>fW (the <cmd>require('wrapping')
	-- calls also lazy-load this plugin). Don't add <leader>fR* lazy keys here or
	-- they show up as a duplicate "Wrapping" group in which-key.
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
