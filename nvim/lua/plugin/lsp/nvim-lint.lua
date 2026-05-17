-- https://www.josean.com/posts/neovim-linting-and-formatting
return {
	-- nvim-lint
	{
		"mfussenegger/nvim-lint",
		event = {
			"BufWritePost",
			"BufReadPre",
			"BufNewFile",
		},
		config = function()
			local lint = require("lint")
			lint.linters_by_ft = {
				markdown = { "markdownlint" },
				cpp = { "cpplint" },
				c = { "cpplint" },
				yaml = { "yamllint" },
				-- python = { "flake8", "pydocstyle" },
				lua = { "luacheck" },
			}
			local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

			-- configure cpplint
			--ref: https://github.com/google/styleguide/blob/gh-pages/cpplint/cpplint.py
			local cpplint = lint.linters.cpplint
			cpplint.args = {
				"--filter=-whitespace/braces,-whitespace/line_length,-whitespace/indent_namespace,-whitespace/tab,"
					.. "-whitespace/tab,-legal/copyright,-build/c++20,-build/header_guard,-readability/todo",
			}
			local cpplint_ns = lint.get_namespace("cpplint")
			vim.diagnostic.config({ virtual_text = false }, cpplint_ns)

			-- configure luacheck
			local luacheck = lint.linters.luacheck
			luacheck.args = {
				"--globals vim",
			}

			-- trigger lint
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
				group = lint_augroup,
				callback = function()
					lint.try_lint()
					lint.try_lint("codespell")
				end,
			})
		end,
	},
	-- mason-nvim-lint
	{
		"rshkarin/mason-nvim-lint",
		version = "v0.1.x",
		event = "VeryLazy",
		dependencies = {
			"williamboman/mason.nvim",
			"mfussenegger/nvim-lint",
		},
		config = function()
			require("mason-nvim-lint").setup({
				ensure_installed = {
					"markdownlint",
					"cpplint",
					"luacheck",
					-- "flake8",
					-- "pydocstyle",
					"yamllint",
					"codespell",
					"commitlint",
				},
				ignore_install = {},
				automatic_installation = true,
				quiet_mode = false,
			})
		end,
	},
}
