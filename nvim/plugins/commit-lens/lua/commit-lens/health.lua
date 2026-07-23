-- Health check for commit-lens: `:checkhealth commit-lens`.
--
-- Neovim auto-discovers `lua/<plugin>/health.lua` and calls its `check()`. This
-- exists mainly because commit-lens' three integrations (nvim-tree, neo-tree,
-- neominimap) are all HOST-SIDE manual wiring (see the plugin README + tree.lua):
-- they can't be attached from inside the plugin, so the single most common
-- "why isn't the mark showing up in my tree/minimap?" is a missing wiring line.
-- This report surfaces exactly that — for every supported integration whose
-- manager is loaded, it confirms the wiring where it can and otherwise prints the
-- adapter's own setup_hint so the fix is copy-pasteable.

local M = {}

-- vim.health.start/ok/info/warn/error is the modern (0.10+) API; this config
-- already relies on newer Neovim (vim.uv, nvim-tree Decorator, neominimap v3).
local h = vim.health

-- Does neominimap's handler list contain our handler? Reliable to detect: the
-- handler table carries a stable `name = "Commit Lens"` (see minimap-handler.lua),
-- and vim.g.neominimap is a plain table the host assembled at startup.
local function neominimap_handler_wired()
	local cfg = vim.g.neominimap
	if type(cfg) ~= "table" or type(cfg.handlers) ~= "table" then
		return false
	end
	for _, handler in pairs(cfg.handlers) do
		if type(handler) == "table" and handler.name == "Commit Lens" then
			return true
		end
	end
	return false
end

function M.check()
	-- --- core: git ----------------------------------------------------------
	h.start("commit-lens: core")
	if vim.fn.executable("git") == 1 then
		local ver = vim.fn.systemlist({ "git", "--version" })[1] or "unknown"
		h.ok("git found (" .. ver .. ")")
	else
		h.error("git not on PATH — commit-lens cannot blame without it", {
			"Install git and ensure it is on your $PATH.",
		})
	end

	-- --- config -------------------------------------------------------------
	h.start("commit-lens: config")
	local ok_core, core = pcall(require, "commit-lens")
	if not ok_core then
		h.error("cannot require 'commit-lens': " .. tostring(core))
		return
	end
	local c = core.config
	h.info("accent = " .. tostring(c.accent) .. ", line_blend = " .. tostring(c.line_blend))
	h.info("blame_args = { " .. table.concat(c.blame_args or {}, ", ") .. " }")
	h.info("blame_jobs = " .. tostring(c.blame_jobs) .. ", render_jobs = " .. tostring(c.render_jobs))
	h.info("max_lines = " .. tostring(c.max_lines) .. ", edit_debounce = " .. tostring(c.edit_debounce) .. "ms")
	h.info(
		"buffer sign glyph = '" .. tostring(c.sign_text) .. "'  (needs a Nerd Font / capable terminal to render)"
	)
	h.info("lens is currently " .. (core.enabled and "ON" or "off"))

	-- --- picker: fzf-lua (optional) -----------------------------------------
	h.start("commit-lens: picker (fzf-lua)")
	if pcall(require, "fzf-lua") then
		h.ok("fzf-lua available — :CommitLens / :CommitLensFiles get the interactive picker")
	else
		h.warn("fzf-lua not found (optional)", {
			"Without it, :CommitLens still works with explicit revs (e.g. :CommitLens <sha>),",
			"and :CommitLensFiles falls back to the quickfix list.",
		})
	end

	-- --- file-tree integrations --------------------------------------------
	h.start("commit-lens: file-tree integrations")
	local ok_tree, tree = pcall(require, "commit-lens.tree")
	if not ok_tree then
		h.warn("tree registry not loaded (" .. tostring(tree) .. ") — no file-tree marks")
	else
		local any = false
		for name, adapter in pairs(tree.registry or {}) do
			local loaded = false
			pcall(function()
				loaded = adapter.detect() == true
			end)
			if loaded then
				any = true
				-- We can't reliably introspect every manager's config to confirm the
				-- decorator/component is wired (the internals differ and shift across
				-- versions), so when the manager is loaded we surface the wiring hint
				-- as a reminder rather than claim a definitive OK.
				h.info(name .. " is loaded")
				if adapter.setup_hint then
					h.info(adapter.setup_hint)
				end
			end
		end
		if not any then
			h.info("no supported file-tree manager loaded (nvim-tree / neo-tree) — nothing to wire")
		end
		h.info("tree marker glyph = '" .. tostring((tree.config or {}).icon) .. "'")
	end

	-- --- neominimap integration --------------------------------------------
	h.start("commit-lens: neominimap")
	if package.loaded["neominimap"] == nil and vim.g.neominimap == nil then
		h.info("neominimap not loaded — minimap marks disabled (nothing to wire)")
	elseif neominimap_handler_wired() then
		h.ok("commit-lens handler registered in vim.g.neominimap.handlers")
	else
		h.warn("neominimap present but the commit-lens handler is NOT in its handlers list", {
			"Add it (safe-required so a missing plugin never breaks startup):",
			"  vim.g.neominimap = {",
			"    handlers = (function()",
			'      local ok, hh = pcall(require, "commit-lens.minimap-handler")',
			"      return ok and { hh } or {}",
			"    end)(),",
			"    -- …rest of your neominimap config…",
			"  }",
		})
	end
end

return M
