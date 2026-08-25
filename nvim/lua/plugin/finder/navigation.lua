return {
	-- nvim tree
	{
		"nvim-tree/nvim-tree.lua",
		version = "^v1",
		cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile", "NvimTreeOpen" },
		keys = {
			{ "<C-B>", "<cmd>NvimTreeToggle<CR>", desc = "Toggle Explorer" },
		},
		-- Eagerly load when nvim was launched on a directory (e.g. `nvim .`)
		-- so it can take over from netrw. Otherwise it stays lazy.
		lazy = (function()
			local argv = vim.fn.argv()
			if #argv ~= 1 then
				return true
			end
			local stat = (vim.uv or vim.loop).fs_stat(argv[1])
			return not (stat and stat.type == "directory")
		end)(),
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				sort = {
					sorter = "case_sensitive",
				},
				view = {
					width = 40,
				},
				update_focused_file = {
					enable = true,
					update_root = { enable = false },
				},
				-- Replace netrw's "open the directory in a buffer" behaviour
				-- so `nvim <folder>` opens nvim-tree on that folder.
				hijack_directories = {
					enable = true,
					auto_open = true,
				},
				renderer = {
					group_empty = true,
					-- Full default decorator list (nvim-tree drops the builtins
					-- if you override `decorators`), with commit-lens appended
					-- before "Cut" so files touched by the chosen commits get a
					-- magenta glyph + name in the tree. commit-lens now keeps
					-- its file-manager glue behind per-manager adapters; this is
					-- the nvim-tree one (the registry drives its refresh).
					decorators = {
						"Git",
						"Open",
						"Hidden",
						"Modified",
						"Bookmark",
						"Diagnostics",
						"Copied",
						require("commit-lens.tree.nvim-tree").decorator,
						"Cut",
					},
				},
				filters = { dotfiles = true },
			})

			local api = require("nvim-tree.api")
			vim.keymap.set("n", "g?", api.tree.toggle_help, {
				desc = "nvim-tree: Help",
				noremap = true,
				silent = true,
				nowait = true,
			})
		end,
	},
	-- Split/pane navigation + resizing, both inside nvim and across tmux panes.
	-- Superset of vim-tmux-navigator: same <C-hjkl> pane navigation (tmux.conf's
	-- TPM plugin + its no-TPM fallback both just forward the raw <C-hjkl> press
	-- into whatever looks vim-like in the pane, so they're agnostic to which
	-- nvim-side plugin owns those keymaps — no tmux.conf changes needed here),
	-- plus directional resize, replacing the hand-written <C-Left/Right/Up/Down>
	-- `:resize` keymaps that used to live in core/keybindings.lua.
	--
	-- Note: vim-tmux-navigator's `<C-\>` "jump to previous tmux pane" has no
	-- equivalent here — smart-splits has no "previous pane" concept, so that
	-- one shortcut is dropped rather than replaced.
	{
		"mrjones2014/smart-splits.nvim",
		keys = {
			{ "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left split/pane" },
			{ "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below split/pane" },
			{ "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above split/pane" },
			{ "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right split/pane" },
			{ "<C-Left>", function() require("smart-splits").resize_left() end, desc = "Resize split left" },
			{ "<C-Right>", function() require("smart-splits").resize_right() end, desc = "Resize split right" },
			{ "<C-Up>", function() require("smart-splits").resize_up() end, desc = "Resize split up" },
			{ "<C-Down>", function() require("smart-splits").resize_down() end, desc = "Resize split down" },
		},
		config = function()
			require("smart-splits").setup({
				-- Match the +2/-2 columns\lines the old hand-written :resize keymaps used.
				default_amount = 2,
				ignored_buftypes = { "nofile", "quickfix", "prompt" },
				ignored_filetypes = { "NvimTree" },
				-- At an edge split, moving/resizing further in that direction forwards
				-- to the adjacent tmux pane instead of no-op'ing.
				multiplexer_integration = "tmux",
			})
		end,
	},
}
