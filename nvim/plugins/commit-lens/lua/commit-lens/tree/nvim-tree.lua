-- nvim-tree adapter for commit-lens.
--
-- nvim-tree is a "render-pipeline injection" manager (see tree.lua): the mark
-- is a Decorator CLASS that must live in the host's `renderer.decorators` list,
-- so it can't be attached from inside commit-lens. The host wires it once —
--
--   renderer.decorators = {
--     "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",
--     require("commit-lens.tree.nvim-tree").decorator,   -- <- here
--     "Cut",
--   }
--
-- (keep the full builtin list; nvim-tree drops the builtins if you override it)
-- and commit-lens only drives the redraw via refresh().
--
-- This module returns the ADAPTER table (name/detect/refresh/setup_hint) with
-- the Decorator class hung off `.decorator`, so one require gives the host both
-- the wiring handle and lets the registry drive refreshes.

local ctx_of = function()
	return require("commit-lens.tree").context()
end

-- ---------------------------------------------------------------------------
-- The Decorator class. nvim-tree constructs a fresh instance every render, so
-- it always reads current lens state. Built lazily on first require of this
-- module, and only if nvim-tree's Decorator base is available.
-- ---------------------------------------------------------------------------
local function build_decorator()
	local ok, api = pcall(require, "nvim-tree.api")
	if not ok or not api.Decorator then
		return nil
	end

	---@class CommitLensDecorator: nvim_tree.api.Decorator
	local D = api.Decorator:extend()

	-- Mandatory no-arg constructor; runs once per tree render.
	function D:new()
		self.enabled = true
		-- Highlight the node *name* (not the whole line) in the accent colour.
		self.highlight_range = "name"
		-- Place the glyph *before* the filename, like gitsigns' tree icons.
		-- "before" needs no define_sign() (that is only for the "signcolumn"
		-- placement), which also sidesteps the sign-registration pitfall.
		self.icon_placement = "before"
		-- Snapshot the lens' file/dir sets + presentation ONCE per render (this
		-- constructor runs once per tree draw). is_hit() then does a plain table
		-- lookup per node instead of require() + field chains for every visible
		-- node — the tree can have hundreds of nodes, so this matters. The
		-- snapshot is fresh because commit-lens refreshes the tree whenever the
		-- sets change.
		local ctx = ctx_of()
		self.cl_icon = ctx.icon
		self.cl_hl = ctx.hl
		if ctx.active then
			self.files = ctx.files
			self.dirs = ctx.dirs
		end
	end

	-- True when this node is a touched file, OR a directory that is an ancestor
	-- of a touched file (so collapsed parents show the marker too —
	-- "passthrough").
	function D:is_hit(node)
		if not self.files or not node or not node.absolute_path then
			return false
		end
		if node.type == "directory" then
			return self.dirs[node.absolute_path] == true
		end
		return self.files[node.absolute_path] == true
	end

	-- Magenta glyph placed before the name of a touched file/ancestor directory.
	function D:icons(node)
		if self:is_hit(node) then
			return { self.cl_icon }
		end
	end

	-- Magenta filename for touched files.
	function D:highlight_group(node)
		if self:is_hit(node) then
			return self.cl_hl
		end
	end

	return D
end

-- Build lazily, and DON'T cache a nil. commit-lens is lazy-loaded, so its
-- tree.setup() may require this module before nvim-tree exists (e.g. you hit
-- `]h` before opening the tree) — at which point build_decorator() returns nil.
-- Lua caches THIS module, so a nil stored here would be permanent, and the
-- host's later `require(...).decorator` (inside nvim-tree's own config, when the
-- base class IS available) would still get nil and silently drop the mark.
-- Expose `.decorator` through a metatable that rebuilds until it succeeds, then
-- memoizes.
local decorator_cache = nil
local function decorator()
	if not decorator_cache then
		decorator_cache = build_decorator()
	end
	return decorator_cache
end

---@type CommitLens.TreeAdapter
local adapter = setmetatable({
	name = "nvim-tree",
	detect = function()
		return package.loaded["nvim-tree"] ~= nil
	end,
	refresh = function()
		pcall(function()
			require("nvim-tree.api").tree.reload()
		end)
	end,
	setup_hint = table.concat({
		"nvim-tree wiring (in your nvim-tree setup, keep the full builtin list):",
		"  renderer = { decorators = {",
		'    "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",',
		'    require("commit-lens.tree.nvim-tree").decorator,',
		'    "Cut",',
		"  } }",
	}, "\n"),
}, {
	-- `.decorator` resolves the Decorator class lazily (see above): reads here
	-- rebuild until nvim-tree's base class is available, so a require that
	-- happens before nvim-tree loads still yields the class once it does.
	__index = function(_, key)
		if key == "decorator" then
			return decorator()
		end
	end,
})

return adapter
