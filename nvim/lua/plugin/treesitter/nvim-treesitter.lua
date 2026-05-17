return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local crisp = require("core.crisp")
		require("nvim-treesitter.configs").setup({
			-- A list of parser names, or "all" (the five listed parsers should always be installed)
			ensure_installed = {
				"bash",
				"c",
				"cmake",
				"cpp",
				"html",
				"json",
				"lua",
				"markdown",
				"markdown_inline",
				"python",
				"regex", -- needed by noice.nvim cmdline highlighting
				"ron",
				"rust",
				"toml",
				"vim",
				"vimdoc",
				"yaml",
				"doxygen",
			},
			-- install parsers synchronously (only applied to `ensure_installed`)
			sync_install = false,

			-- Automatically install missing parsers when entering buffer
			-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
			auto_install = false,

			-- List of parsers to ignore installing (or "all")
			ignore_install = { "" },

			highlight = {
				enable = true,
				-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
				-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
				-- Using this option may slow down your editor, and you may see some duplicate highlights.
				-- Instead of true it can also be a list of languages
				additional_vim_regex_highlighting = false,
				disable = function(_, buf)
					return crisp.isBigFile(buf)
				end,
			},
			indent = { enable = true, disable = { "yaml" } },
		})
	end,
}
