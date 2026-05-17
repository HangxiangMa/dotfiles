local keymap_opts = { noremap = true, silent = true }
return {
	-- support virtual whitespace display when code selection happens in virtual mode
	{
		"mcauley-penney/visual-whitespace.nvim",
		config = true,
		event = "ModeChanged *:[vV\22]", -- optionally, lazy load on entering visual mode
		init = function()
			vim.keymap.set({ "n", "v" }, "<leader><leader>v", require("visual-whitespace").toggle, keymap_opts)
		end,
		opts = {},
	},
	-- support trailing space display and trimming
	{
		"echasnovski/mini.trailspace",
		version = "*",
		event = "ModeChanged *:[nN\22]", -- optionally, lazy load on entering visual mode
		config = function()
			local trailspace = require("mini.trailspace")
			trailspace.setup({
				-- Highlight only in normal buffers (ones with empty 'buftype'). This is
				-- useful to not show trailing whitespace where it usually doesn't matter.
				only_in_normal_buffers = true,
				vim.keymap.set({ "n", "v" }, "<leader><leader>s", trailspace.trim, keymap_opts),
				vim.keymap.set({ "n", "v" }, "<leader><leader>l", trailspace.trim_last_lines, keymap_opts),
			})
		end,
	},
}
