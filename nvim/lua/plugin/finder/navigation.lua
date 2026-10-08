local uv = vim.uv or vim.loop

-- nvim-tree creates one libuv fs-event watcher per directory. Large Android
-- and Linux kernel trees can contain more directories than the host's inotify
-- quota, making every failed watcher start emit another notification. Detect
-- the source root without walking it so we can keep the tree usable but skip
-- watchers.
local function is_directory(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == "directory"
end

local function is_file(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == "file"
end

local function normalize_path(path)
	if not path or path == "" then
		return nil
	end

	local normalized = vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
	if normalized ~= "/" then
		normalized = normalized:gsub("/+$", "")
	end
	return normalized
end

local function is_large_source_root(path)
	return (is_directory(path .. "/.repo")
		and is_directory(path .. "/build")
		and is_directory(path .. "/vendor"))
		or (is_file(path .. "/Makefile")
			and is_file(path .. "/Kconfig")
			and is_directory(path .. "/arch")
			and is_directory(path .. "/drivers")
			and is_directory(path .. "/include")
			and is_directory(path .. "/scripts"))
end

local function find_large_source_root(path)
	local candidate = normalize_path(path)
	if not candidate or not is_directory(candidate) then
		return nil
	end

	-- Check a few ancestors so opening a directory below the checkout still
	-- gets the same protection. No recursive filesystem scan is performed.
	for _ = 1, 8 do
		if is_large_source_root(candidate) then
			return candidate
		end

		local parent = normalize_path(candidate .. "/..")
		if not parent or parent == candidate then
			break
		end
		candidate = parent
	end
end

local function launch_directory()
	local argv = vim.fn.argv()
	if #argv == 1 then
		local stat = uv.fs_stat(argv[1])
		if stat and stat.type == "directory" then
			return argv[1]
		end
	end
	return vim.fn.getcwd()
end

local large_source_root = find_large_source_root(launch_directory())
local large_source_tree = large_source_root ~= nil

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
				-- A large source checkout can exhaust inotify watchers. Without this
				-- gate nvim-tree reports one warning for every failed watcher,
				-- flooding the notification UI during startup. Manual refresh and
				-- navigation remain available with watchers disabled.
				filesystem_watchers = {
					enable = not large_source_tree,
				},
				-- Git status starts another scan over the same huge tree. Disable it
				-- for this nvim session; normal projects keep the default behavior.
				git = {
					enable = not large_source_tree,
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
	-- Split/pane navigation + resizing, both inside nvim and across Herdr panes.
	-- The Herdr integration uses the same <C-hjkl> chords in both applications:
	-- Herdr's smart-splits plugin forwards them to nvim, and smart-splits crosses
	-- the Herdr boundary when nvim is at an edge.
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
				-- At an edge split, moving further in that direction crosses into the
				-- adjacent Herdr pane instead of wrapping inside nvim.
				multiplexer_integration = "herdr",
			})
		end,
	},
}
