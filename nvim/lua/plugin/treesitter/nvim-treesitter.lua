return {
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local crisp = require("core.crisp")

			require("nvim-treesitter").setup({})

			require("nvim-treesitter").install({
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
				"regex",
				"ron",
				"rust",
				"toml",
				"vim",
				"vimdoc",
				"yaml",
				"doxygen",
			})

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					if crisp.isBigFile(args.buf) then
						return
					end
					pcall(vim.treesitter.start)
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "yaml" },
				callback = function()
					vim.bo.indentexpr = ""
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					if vim.bo.filetype ~= "yaml" then
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = { lookahead = true },
				move = { set_jumps = true },
			})

			local select = require("nvim-treesitter-textobjects.select")
			local move = require("nvim-treesitter-textobjects.move")
			local swap = require("nvim-treesitter-textobjects.swap")

			-- select
			local select_maps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["a/"] = "@comment.outer",
				["i/"] = "@comment.inner",
			}
			for key, query in pairs(select_maps) do
				vim.keymap.set({ "x", "o" }, key, function()
					select.select_textobject(query, "textobjects")
				end)
			end

			-- move
			local move_maps = {
				["]f"] = { "goto_next_start", "@function.outer" },
				["]c"] = { "goto_next_start", "@class.outer" },
				["]a"] = { "goto_next_start", "@parameter.inner" },
				["]F"] = { "goto_next_end", "@function.outer" },
				["]C"] = { "goto_next_end", "@class.outer" },
				["[f"] = { "goto_previous_start", "@function.outer" },
				["[c"] = { "goto_previous_start", "@class.outer" },
				["[a"] = { "goto_previous_start", "@parameter.inner" },
				["[F"] = { "goto_previous_end", "@function.outer" },
				["[C"] = { "goto_previous_end", "@class.outer" },
			}
			for key, spec in pairs(move_maps) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move[spec[1]](spec[2], "textobjects")
				end)
			end

			-- swap
			vim.keymap.set("n", "<leader>cna", function()
				swap.swap_next("@parameter.inner")
			end)
			vim.keymap.set("n", "<leader>cpa", function()
				swap.swap_previous("@parameter.inner")
			end)
		end,
	},
}
