return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	init = function()
		vim.filetype.add({
			pattern = {
				[".*"] = {
					function(path, buf)
						if not buf or vim.bo[buf].filetype == "bigfile" then
							return
						end
						local line_count = vim.api.nvim_buf_line_count(buf)
						if line_count > 2048 then
							return "bigfile"
						end
					end,
					{ priority = -math.huge },
				},
			},
		})
	end,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = {
			enabled = true,
			size = 1024 * 1024, -- 1MB
			---@param ctx {buf: number, ft:string}
			setup = function(ctx)
				if vim.fn.exists(":NoMatchParen") ~= 0 then
					vim.cmd([[NoMatchParen]])
				end
				Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
				vim.b.completion = false
				vim.b.minianimate_disable = true
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(ctx.buf) then
						vim.bo[ctx.buf].syntax = ctx.ft
					end
				end)
			end,
		},
		dashboard = { enabled = false },
		indent = { enabled = false },
		input = { enabled = true },
		notifier = { enabled = true },
		picker = { enabled = true }, -- powers Snacks.picker.smart (frecency)
		quickfile = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = true },
	},
	keys = {
		{
			"<leader>fo",
			function()
				require("snacks").picker.smart()
			end,
			desc = "Smart Open (frecency)",
		},
		{
			"<leader>fO",
			function()
				require("snacks").picker.smart({ cwd = vim.fn.getcwd() })
			end,
			desc = "Smart Open (CWD)",
		},
	},
}
