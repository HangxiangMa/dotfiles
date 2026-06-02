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
		bufdelete = { enabled = true }, -- delete buffers without wrecking the window layout
		dashboard = { enabled = false },
		-- explorer intentionally disabled: it sets replace_netrw=true and installs
		-- a BufEnter directory-hijack handler that fights nvim-tree's
		-- hijack_directories/auto_open. nvim-tree owns the file-tree role.
		explorer = { enabled = false },
		indent = { enabled = false },
		input = { enabled = true },
		-- notifier intentionally disabled: noice + nvim-notify own vim.notify.
		-- Enabling snacks.notifier here was redundant (noice loads on VeryLazy,
		-- i.e. last, so it always won the vim.notify override anyway).
		notifier = { enabled = false },
		picker = { enabled = true }, -- powers Snacks.picker.smart (frecency) + explorer
		quickfile = { enabled = true },
		scope = { enabled = true }, -- indent-based scope textobjects + edge jumps (see keys)
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
		-- Lazygit (replaces lazygit.nvim + toggleterm's lazygit term)
		{
			"<leader>gg",
			function()
				require("snacks").lazygit()
			end,
			desc = "Lazygit",
		},
		{
			"<leader>gG",
			function()
				require("snacks").lazygit.log_file()
			end,
			desc = "Lazygit Current File History",
		},
		-- Open current file/line on the git remote in a browser
		{
			"<leader>gO",
			function()
				require("snacks").gitbrowse()
			end,
			mode = { "n", "v" },
			desc = "Git Browse (open in browser)",
		},
		-- Scope textobjects (indent-based) — complements the treesitter
		-- af/if/ac/ic objects with a whitespace-scope object.
		{
			"ii",
			function()
				require("snacks").scope.textobject()
			end,
			mode = { "x", "o" },
			desc = "Inner Scope",
		},
		{
			"ai",
			function()
				require("snacks").scope.textobject({ edge = true })
			end,
			mode = { "x", "o" },
			desc = "Around Scope",
		},
		-- Jump to the top / bottom edge of the current scope.
		{
			"[i",
			function()
				require("snacks").scope.jump({ bottom = false })
			end,
			mode = { "n", "x", "o" },
			desc = "Jump to Scope Top",
		},
		{
			"]i",
			function()
				require("snacks").scope.jump({ bottom = true })
			end,
			mode = { "n", "x", "o" },
			desc = "Jump to Scope Bottom",
		},
	},
	config = function(_, opts)
		local Snacks = require("snacks")
		Snacks.setup(opts)

		-- Toggle framework: a set of UI/option toggles under <leader>u.
		-- Each :map() creates the keymap; which-key picks up the names.
		Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
		Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
		Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
		Snacks.toggle.line_number():map("<leader>ul")
		Snacks.toggle
			.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
			:map("<leader>uc")
		Snacks.toggle.diagnostics():map("<leader>ud")
		Snacks.toggle.treesitter():map("<leader>uT")
		Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
		Snacks.toggle.dim():map("<leader>uD")
	end,
}
