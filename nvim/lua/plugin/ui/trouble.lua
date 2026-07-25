return {
	"folke/trouble.nvim",
	cmd = "Trouble",
	dependencies = "nvim-tree/nvim-web-devicons",
	opts = {
		-- Preview in the real (loaded) file buffer instead of a scratch buffer.
		-- Scratch previews never set `filetype`, so our FileType-driven highlighting
		-- (treesitter start + syntax/c.lua + syntax/cpp.lua) never fires and the
		-- preview renders without colors -- most visibly on the bottom codespell
		-- (INFO) items, which usually point at files that aren't open yet.
		preview = { scratch = false },
		icons = {
			indent = {
				middle = " ",
				last = " ",
				top = " ",
				ws = "│  ",
			},
		},
		modes = {
			diagnostics = {
				groups = {
					{ "filename", format = "{file_icon} {basename:Title} {count}" },
				},
			},
			-- Diagnostics for the current buffer and errors from the current project
			mydiags = {
				mode = "diagnostics", -- inherit from diagnostics mode
				filter = {
					any = {
						buf = 0, -- current buffer
						{
							severity = vim.diagnostic.severity.ERROR, -- errors only
							-- limit to files in the current project
							function(item)
								return item.filename:find((vim.uv or vim.loop).cwd(), 1, true)
							end,
						},
					},
				},
			},
		},
	},
}
