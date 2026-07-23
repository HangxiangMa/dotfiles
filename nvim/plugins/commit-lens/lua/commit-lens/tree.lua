-- commit-lens tree-manager registry.
--
-- commit-lens marks, in your file-tree, every file a chosen commit still owns
-- (blame-confirmed) plus its ancestor directories. Different tree plugins wire
-- up in very different ways, so the coupling is isolated behind small adapters:
-- THIS module owns "which managers do we drive" + "redraw them"; each
-- lua/commit-lens/tree/<name>.lua owns the manager-specific glue.
--
-- Two integration shapes exist in the wild, and the difference decides how much
-- can be automatic:
--   * render-pipeline injection (nvim-tree Decorator, neo-tree component): a
--     component must be placed into the MANAGER's own setup config, so it can't
--     be attached after the fact — the host wires it in once (see the adapter's
--     `setup_hint`), and commit-lens only drives the redraw via refresh().
--   * buffer + extmark (oil, mini.files, snacks explorer): the manager renders
--     a real buffer, so an adapter's `attach(ctx)` can self-wire an autocmd and
--     paint extmarks directly — no host wiring needed.
--
-- Only the nvim-tree adapter ships today; this interface is here so the rest
-- slot in without touching core.
--
---@class CommitLens.TreeAdapter
---@field name        string                    -- manager key, e.g. "nvim-tree"
---@field detect      fun():boolean              -- is the manager currently loaded?
---@field refresh     fun()                      -- ask the manager to redraw
---@field attach?     fun(ctx:CommitLens.TreeContext):boolean|nil  -- optional: self-wire hooks (buffer-type)
---@field setup_hint? string                     -- optional: manual-wiring snippet (injection-type)

local M = {}

---@class CommitLens.TreeConfig
M.config = {
	-- "auto"  → drive every registered manager that is currently loaded.
	-- {names} → drive only these (e.g. {"nvim-tree"}); {} disables the tree layer.
	managers = "auto",
	-- Marker glyph before a touched entry: nf-oct git-commit U+F417, written as
	-- explicit UTF-8 bytes (EF 90 97) so this Private-Use-Area codepoint survives
	-- file transfer intact (same pitfall as the buffer sign; see init.lua).
	icon = "\239\144\151",
}

-- name -> adapter. Populated by setup() from the builtin list.
M.registry = {}
-- "auto" | "list". In list mode only names in `enabled` are driven.
M.mode = "auto"
M.enabled = {}

-- Adapters shipped with commit-lens. Each is a side-effect-free module (it
-- lazy-requires its manager's API only inside functions), so requiring one when
-- its manager isn't installed is safe.
local BUILTIN = { "nvim-tree", "neo-tree" }

-- Read-only view of lens state + presentation that adapters render from.
-- Rebuilt cheaply on demand (e.g. once per nvim-tree render). The file/dir
-- tables are live refs into core — adapters must treat them as READ-ONLY.
---@class CommitLens.TreeContext
---@field active boolean
---@field files  table<string,boolean>
---@field dirs   table<string,boolean>
---@field icon   { str: string, hl: string[] }
---@field hl     string
---@field is_hit fun(path:string, is_dir:boolean):boolean
function M.context()
	local core = require("commit-lens")
	return {
		active = core.enabled,
		files = core.tree_files,
		dirs = core.tree_dirs,
		icon = { str = M.config.icon, hl = { "CommitLensSign" } },
		hl = "CommitLensSign",
		is_hit = function(path, is_dir)
			if not core.enabled or not path then
				return false
			end
			if is_dir then
				return core.tree_dirs[path] == true
			end
			return core.tree_files[path] == true
		end,
	}
end

local function is_enabled(name)
	if M.mode == "auto" then
		return true
	end
	return M.enabled[name] == true
end

-- Ask every enabled + loaded manager to redraw so its commit-lens adapter picks
-- up the new touched sets. Called from core on activate/clear. detect() is
-- evaluated HERE (not at setup) so a manager that loads lazily — after
-- commit-lens.setup() — is still driven; safe no-op when none is loaded.
function M.refresh()
	for name, adapter in pairs(M.registry) do
		if is_enabled(name) and adapter.detect() then
			pcall(adapter.refresh)
		end
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Register builtin adapters (idempotent across repeated setup()).
	for _, name in ipairs(BUILTIN) do
		if not M.registry[name] then
			local ok, adapter = pcall(require, "commit-lens.tree." .. name)
			if ok and type(adapter) == "table" then
				M.registry[adapter.name or name] = adapter
			end
		end
	end

	local managers = M.config.managers
	if managers == nil or managers == "auto" then
		M.mode = "auto"
	else
		M.mode = "list"
		M.enabled = {}
		if type(managers) == "table" then
			for _, name in ipairs(managers) do
				M.enabled[name] = true
			end
		end
	end

	-- Buffer-type adapters can self-wire; give each enabled + already-loaded
	-- adapter that offers attach() a chance to hook itself now. (No builtin uses
	-- this yet — injection-type adapters are wired by the host, see setup_hint.)
	for name, adapter in pairs(M.registry) do
		if is_enabled(name) and adapter.attach and adapter.detect() then
			pcall(adapter.attach, M.context())
		end
	end
end

return M
