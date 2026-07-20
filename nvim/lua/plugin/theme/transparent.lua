-- transparent.nvim — clears background highlight groups so the terminal's own
-- background (and any transparency/blur the terminal provides) shows through.
-- Works standalone with onedark; it hooks the ColorScheme autocmd, so it
-- reapplies whenever the colorscheme is (re)loaded.
--
-- The plugin caches its enabled state across sessions, so we force it off at
-- startup: transparency is disabled by default and is opt-in per session via
-- <leader>ut (or :TransparentToggle / :TransparentEnable / :TransparentDisable).
return {
	"xiyaowong/transparent.nvim",
	enabled = true,
	lazy = false, -- README warns against lazy-loading: the clear must run at startup
	init = function()
		-- Setting the flag to a non-nil value stops the plugin from reading its
		-- persisted cache on load, so a session that toggled it on won't bleed
		-- back into the next startup. Default = disabled.
		vim.g.transparent_enabled = false
	end,
	keys = {
		{ "<leader>ut", "<cmd>TransparentToggle<cr>", desc = "Toggle Transparency" },
	},
	opts = {
		-- Extra groups to clear on top of the built-in defaults (Normal,
		-- LineNr, SignColumn, StatusLine, CursorLine, EndOfBuffer, …).
		extra_groups = {
			"NormalFloat", -- float panels: Lazy, Mason, LspInfo, noice, …
			"FloatBorder",
			"NvimTreeNormal",
			"NvimTreeNormalNC",
			"NvimTreeEndOfBuffer",
		},
		-- Plugins that name their highlight groups dynamically need a prefix
		-- clear so their backgrounds go transparent too. clear_prefix is meant
		-- to be called from on_clear (fires after the default groups are cleared).
		on_clear = function()
			local transparent = require("transparent")
			transparent.clear_prefix("BufferLine")
			transparent.clear_prefix("lualine")
			transparent.clear_prefix("Neominimap")
		end,
	},
}
