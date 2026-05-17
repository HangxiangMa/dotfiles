return {
	{
		--- https://www.lazyvim.org/extras/editor/fzf
		"ibhagwan/fzf-lua",
		cmd = "FzfLua",
		dependencies = {
			-- we need to ensure the fzf has been installed
			{ "junegunn/fzf", name = "fzf", build = "./install --bin" },
			{ "nvim-tree/nvim-web-devicons", lazy = false },
		},
		-- fzf is installed under lazy's plugin dir; prepend its bin/ to $PATH
		-- so fzf-lua (and :checkhealth) can find the binary without relying on
		-- a system-wide install.
		init = function()
			local fzf_bin = vim.fn.stdpath("data") .. "/lazy/fzf/bin"
			if vim.fn.isdirectory(fzf_bin) == 1 and not vim.env.PATH:find(fzf_bin, 1, true) then
				vim.env.PATH = fzf_bin .. ":" .. vim.env.PATH
			end
		end,
		opts = function(_, opts)
			-- calling `setup` is optional for customization
			local fzf = require("fzf-lua")
			local config = fzf.config
			local actions = fzf.actions

			-- Quickfix
			config.defaults.keymap.fzf["ctrl-q"] = "select-all+accept"
			config.defaults.keymap.fzf["ctrl-u"] = "half-page-up"
			config.defaults.keymap.fzf["ctrl-d"] = "half-page-down"
			config.defaults.keymap.fzf["ctrl-x"] = "jump"
			config.defaults.keymap.fzf["ctrl-f"] = "preview-page-down"
			config.defaults.keymap.fzf["ctrl-b"] = "preview-page-up"
			config.defaults.keymap.builtin["<c-f>"] = "preview-page-down"
			config.defaults.keymap.builtin["<c-b>"] = "preview-page-up"
			-- Trouble
			config.defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open

			local img_previewer ---@type string[]?
			for _, v in ipairs({
				{ cmd = "ueberzug", args = {} },
				{ cmd = "chafa", args = { "{file}", "--format=symbols" } },
				{ cmd = "viu", args = { "-b" } },
			}) do
				if vim.fn.executable(v.cmd) == 1 then
					img_previewer = vim.list_extend({ v.cmd }, v.args)
					break
				end
			end
			return {
				"default-title",
				fzf_colors = true,
				fzf_opts = {
					["--no-scrollbar"] = true,
				},
				defaults = {
					-- formatter = "path.filename_first",
					formatter = "path.dirname_first",
				},
				previewers = {
					builtin = {
						extensions = {
							["png"] = img_previewer,
							["jpg"] = img_previewer,
							["jpeg"] = img_previewer,
							["gif"] = img_previewer,
							["webp"] = img_previewer,
						},
						ueberzug_scaler = "fit_contain",
					},
				},
				-- Custom LazyVim option to configure vim.ui.select
				ui_select = function(fzf_opts, items)
					return vim.tbl_deep_extend("force", fzf_opts, {
						prompt = " ",
						winopts = {
							title = " " .. vim.trim((fzf_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " ",
							title_pos = "center",
						},
					}, fzf_opts.kind == "codeaction" and {
						winopts = {
							layout = "vertical",
							-- height is number of items minus 15 lines for the preview, with a max of 80% screen height
							height = math.floor(math.min(vim.o.lines * 0.8 - 16, #items + 2) + 0.5) + 16,
							width = 0.5,
							preview = {
								layout = "vertical",
								vertical = "down:15,border-top",
							},
						},
					} or {
						winopts = {
							width = 0.5,
							-- height is number of items, with a max of 80% screen height
							height = math.floor(math.min(vim.o.lines * 0.8, #items + 2) + 0.5),
						},
					})
				end,
				winopts = {
					width = 0.8,
					height = 0.8,
					row = 0.5,
					col = 0.5,
					preview = {
						scrollchars = { "┃", "" },
					},
				},
				files = {
					cwd_prompt = false,
					actions = {
						["alt-i"] = { actions.toggle_ignore },
						["alt-h"] = { actions.toggle_hidden },
					},
				},
				grep = {
					actions = {
						["alt-i"] = { actions.toggle_ignore },
						["alt-h"] = { actions.toggle_hidden },
					},
				},
				lsp = {
					symbols = {
						symbol_hl = function(s)
							return "TroubleIcon" .. s
						end,
						symbol_fmt = function(s)
							return s:lower() .. "\t"
						end,
						child_prefix = false,
					},
					code_actions = {
						previewer = vim.fn.executable("delta") == 1 and "codeaction_native" or nil,
					},
				},
			}
		end,
		config = function(_, opts)
			if opts[1] == "default-title" then
				-- use the same prompt for all pickers for profile `default-title` and
				-- profiles that use `default-title` as base profile
				local function fix(t)
					t.prompt = t.prompt ~= nil and " " or nil
					for _, v in pairs(t) do
						if type(v) == "table" then
							fix(v)
						end
					end
					return t
				end
				opts = vim.tbl_deep_extend("force", fix(require("fzf-lua.profiles.default-title")), opts)
				opts[1] = nil
			end
			require("fzf-lua").setup(opts)

			-- If the user switches away from the fzf floating window with <C-w>,
			-- close it automatically. fzf's own quit keys (<Esc>/<C-c>) only
			-- work while focus is inside its terminal buffer, so without this
			-- the window becomes unreachable until you re-enter it.
			vim.api.nvim_create_autocmd("WinLeave", {
				group = vim.api.nvim_create_augroup("user_fzf_autoclose", { clear = true }),
				callback = function()
					if vim.bo.filetype == "fzf" then
						local win = vim.api.nvim_get_current_win()
						vim.schedule(function()
							if vim.api.nvim_win_is_valid(win) then
								pcall(vim.api.nvim_win_close, win, true)
							end
						end)
					end
				end,
			})
		end,
	},
}
