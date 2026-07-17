-- nvim-tree decorator for commit-lens: marks tree entries whose file was
-- touched by the chosen commit(s) with a magenta git-commit glyph *before the
-- name* plus a magenta filename — the same "before" placement gitsigns uses in
-- the tree — so you can see at a glance which files the lens affects.
--
-- Registered by adding this class to nvim-tree's `renderer.decorators`
-- (see lua/plugin/finder/navigation.lua). nvim-tree constructs a fresh
-- instance on every render, so it always reads the current commit-lens state.
--
-- The touched sets live on the commit-lens module: M.tree_files (absolute file
-- path -> true) and M.tree_dirs (ancestor directory -> true), both populated in
-- activate() and emptied in clear().

local Decorator = require("nvim-tree.api").Decorator

-- Lazily fetch the commit-lens module. This decorator may be constructed
-- (during nvim-tree's first render) before commit-lens has been triggered, so
-- resolve it on demand and tolerate its absence.
local function lens()
	local ok, m = pcall(require, "commit-lens")
	return ok and m or nil
end

---@class CommitLensDecorator: nvim_tree.api.Decorator
local D = Decorator:extend()

-- Mandatory no-arg constructor; runs once per tree render.
function D:new()
	self.enabled = true
	-- Highlight the node *name* (not the whole line) in the accent colour.
	self.highlight_range = "name"
	-- Place the glyph *before* the filename, like gitsigns' tree icons.
	-- "before" needs no define_sign() (that is only for the "signcolumn"
	-- placement), which also sidesteps the sign-registration pitfall.
	self.icon_placement = "before"
	-- A DISTINCT tree marker, decoupled from the buffer's "│" sign: the
	-- nf-oct git_commit glyph U+F417 (a dot on a line), written as explicit
	-- UTF-8 bytes (EF 90 97) so this Private-Use-Area codepoint survives file
	-- transfer intact. Shares the magenta CommitLensSign highlight.
	self.cl_icon = { str = "\239\144\151", hl = { "CommitLensSign" } }
	-- Snapshot the lens' file/dir sets ONCE per render (this constructor runs
	-- once per tree draw). is_hit() then does a plain table lookup per node
	-- instead of pcall(require) + field chains for every visible node — the
	-- tree can have hundreds of nodes, so this matters. The snapshot is fresh
	-- because commit-lens calls tree.reload() whenever the sets change.
	local l = lens()
	if l and l.enabled then
		self.files = l.tree_files
		self.dirs = l.tree_dirs
	end
end

-- True when this node is a touched file, OR a directory that is an ancestor
-- of a touched file (so collapsed parents show the marker too — "passthrough").
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
		return "CommitLensSign"
	end
end

return D
