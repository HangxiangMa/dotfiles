-- neominimap handler for commit-lens: shows the lens' marked lines on the
-- minimap in orange, the same way neominimap's built-in git handler shows
-- gitsigns hunks in green/red.
--
-- Registered via `vim.g.neominimap.handlers` (neominimap's public custom-handler
-- API). It folds the buffer's *live* commit-lens extmarks into blocks via
-- `commit-lens.get_blocks` (block = a contiguous run of marked lines), so it
-- costs nothing extra — no second blame, and no stale snapshot. Because it reads
-- the extmarks (which Neovim auto-shifts on every edit) rather than a table
-- captured at blame time, the minimap marks realign the instant neominimap
-- repaints, instead of lagging behind the debounced (up to 1.6s + blame)
-- re-render. commit-lens fires `User CommitLensUpdate` on activate/clear/refresh,
-- and neominimap's own text-update cycle also re-polls this handler.
--
-- Return this module's table from your neominimap `handlers` list.

local api = vim.api

-- We reuse commit-lens' own "CommitLensSign" group (orange fg) directly rather
-- than defining a minimap-specific one. The core module already creates it in
-- setup() and re-asserts it on ColorScheme, so the minimap tracks the theme
-- with no timing/override races of our own.

---@type Neominimap.Map.Handler
return {
	name = "Commit Lens",
	-- "sign" = braille dots in the minimap sign column, like the git handler.
	mode = "sign",
	namespace = api.nvim_create_namespace("neominimap_commit_lens"),
	autocmds = {
		{
			event = "User",
			opts = {
				pattern = "CommitLensUpdate",
				desc = "Update commit-lens annotations on the minimap",
				get_buffers = function(args)
					if not args.data then
						return nil
					end
					return tonumber(args.data.buffer)
				end,
			},
		},
	},
	init = function() end,
	---@param bufnr integer
	---@return Neominimap.Map.Handler.Annotation[]
	get_annotations = function(bufnr)
		local ok, cl = pcall(require, "commit-lens")
		if not ok then
			return {}
		end
		local blocks = cl.get_blocks(bufnr)
		local annotations = {}
		for _, b in ipairs(blocks) do
			annotations[#annotations + 1] = {
				lnum = b.first,
				end_lnum = b.last,
				id = 1,
				-- Lowest priority on the minimap: neominimap draws each handler's
				-- signs as extmarks whose `priority` decides who wins a shared
				-- minimap cell. The built-in git handler uses 6, so priority 1
				-- lets gitsigns' green/red (your live working-tree edits) always
				-- cover the commit-lens historical marks.
				priority = 1,
				highlight = "CommitLensSign",
			}
		end
		return annotations
	end,
}
