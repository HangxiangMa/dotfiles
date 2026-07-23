-- neo-tree adapter for commit-lens.
--
-- Like nvim-tree, neo-tree is a "render-pipeline injection" manager (see
-- tree.lua): the mark is produced by a *component* that must live in neo-tree's
-- own setup config, so commit-lens can't attach it after the fact — the host
-- wires it once and commit-lens only drives the redraw via refresh().
--
-- neo-tree's component model: a component is `fun(config, node, state)` that
-- returns `{ text=, highlight= }` OR a LIST of such segments (the renderer
-- concatenates a list). Custom components are registered by NAME under a
-- source's `components` table and are deep-merged over the builtins, so a
-- component you define with a builtin's name REPLACES it while leaving the rest
-- of the config intact.
--
-- Why we override the builtin `name` component (and nothing else): renderer
-- *lists* are replaced wholesale on merge (specify `renderers.file` and you must
-- reproduce the entire default list — fragile across neo-tree versions). The
-- `name` component, by contrast, is already referenced in every default
-- renderer, and overriding it deep-merges cleanly. By returning a two-segment
-- list — [glyph, filename] — from our `name` override we get BOTH the
-- glyph-before-name AND the recoloured filename with zero renderer-list
-- rewriting. That is the whole trick, and it's what keeps this robust.
--
-- Host wiring (see setup_hint):
--   require("neo-tree").setup({
--     filesystem = { components = {
--       name = require("commit-lens.tree.neo-tree").name_component,
--     } },
--   })

local function ctx_of()
	return require("commit-lens.tree").context()
end

-- Our `name` override: delegate to neo-tree's builtin `name` to get the correct
-- base text/highlight (root-name, directory, git-status colours, filters — all
-- of that logic stays in neo-tree), then, only for a touched node, prepend the
-- magenta glyph and recolour the filename. Untouched nodes pass straight
-- through unchanged.
local function name_component(config, node, state)
	local common = require("neo-tree.sources.common.components")
	local base = common.name(config, node, state)
	local ctx = ctx_of()
	if not ctx.active or not node or not node.path then
		return base
	end
	if not ctx.is_hit(node.path, node.type == "directory") then
		return base
	end
	-- Two segments in place of the single name segment: glyph then filename,
	-- both in the accent highlight. base.text carries neo-tree's resolved
	-- filename (incl. any trailing decorations it added).
	return {
		{ text = ctx.icon.str .. " ", highlight = ctx.hl },
		{ text = base.text, highlight = ctx.hl },
	}
end

---@type CommitLens.TreeAdapter
local adapter = {
	name = "neo-tree",
	-- The host drops this into `filesystem.components.name` (or any source's
	-- `components.name`). Exposed as a plain field, mirroring how the nvim-tree
	-- adapter exposes `.decorator`.
	name_component = name_component,
	detect = function()
		return package.loaded["neo-tree"] ~= nil
	end,
	refresh = function()
		-- redraw() re-renders from existing nodes without re-scanning the
		-- filesystem — exactly right when only our touched set changed. Guarded:
		-- no-op if neo-tree isn't loaded or no filesystem tree is open.
		pcall(function()
			require("neo-tree.sources.manager").redraw("filesystem")
		end)
	end,
	setup_hint = table.concat({
		"neo-tree wiring (override just the `name` component; no renderer edits):",
		'  require("neo-tree").setup({',
		"    filesystem = { components = {",
		'      name = require("commit-lens.tree.neo-tree").name_component,',
		"    } },",
		"  })",
	}, "\n"),
}

return adapter
