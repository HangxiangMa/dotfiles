-- commit-lens: annotate the *current* code with the lines that belong to a
-- chosen set of commits, as an independent highlight layer.
--
-- Why this exists (and how it differs from what you already have):
--   * diffview (:DiffviewFileHistory) shows changes in a *separate* buffer —
--     fragmentary, not overlaid on the code you are editing.
--   * gitsigns' change_base can only hold ONE diff base, and it diffs the
--     working tree against that rev, so your own new edits get mixed in with
--     the commit's changes. It is a mode switch, per-file.
--
-- commit-lens instead runs `git blame` on the current buffer and marks the
-- lines whose commit is in your chosen set. That means:
--   * multiple commits at once (union of their surviving lines);
--   * your later edits are NOT attributed to those commits (blame only claims
--     lines that genuinely belong to them) — no "location confusion";
--   * a private namespace that coexists with gitsigns' working-tree signs.
--
-- Blame is the single source of truth: the buffer highlight, the nvim-tree
-- decorator, and the neominimap handler all key off the same blame result, so
-- a file marked in the tree always has surviving lines when you open it.
--
-- Blame runs asynchronously (vim.system) and is cached per buffer by
-- (commit-set version, changedtick), so switching buffers never re-blames
-- unnecessarily and never blocks the UI.
--
-- Known limitation (by design): blame can only mark lines from the commit that
-- *survive* into the current code. A commit whose changes were later fully
-- overwritten (or a pure-deletion commit) has no surviving line to mark — such
-- files are intentionally NOT marked. Use diffview to inspect those.

local M = {}

---@class CommitLens.Config
---@field sign_text string          -- buffer sign glyph (magenta via CommitLensSign)
---@field accent string             -- the one accent colour, e.g. "#FF5FD7"
---@field line_blend number         -- accent→Normal-bg blend for the line tint (0..1)
---@field priority integer          -- buffer extmark/sign priority (gitsigns = 6)
---@field max_lines integer         -- skip buffers with more lines than this
---@field skip_filetypes table<string,boolean>  -- filetypes to skip
---@field blame_args string[]       -- flags spliced into every `git blame` (e.g. {"-w","-M"})
---@field blame_jobs integer        -- max concurrent tree-refinement blames
---@field render_jobs integer       -- max concurrent buffer-render blames
---@field edit_debounce integer     -- ms to debounce re-blame after an edit (scaled by size)
---@field tree CommitLens.TreeConfig  -- file-tree integration (see tree.lua)

-- Default config; overridable via setup(opts).
---@type CommitLens.Config
M.config = {
	-- Sign glyph for a commit-lens line in the *buffer*: the same vertical bar
	-- "│" gitsigns uses. We don't invent a distinct glyph here — the magenta
	-- CommitLensSign colour already tells it apart from gitsigns' green/red
	-- bars. (The nvim-tree marker is a separate git-commit glyph; see
	-- tree-decorator.lua.) Written as explicit UTF-8 bytes (E2 94 82) so it
	-- survives file transfer intact.
	sign_text = "\226\148\130",
	-- The accent colour: magenta. Deliberately NOT the config's orange
	-- (#D19A66) — that collides exactly with onedark's @type.builtin and is
	-- near struct/type yellow (#E5C07B), which made the minimap dots
	-- indistinguishable. Magenta is unused by gitsigns (green/blue/red),
	-- diagnostics (yellow/cyan/purple), and type highlights, so it reads
	-- clearly in the buffer, the tree, and the minimap.
	accent = "#FF5FD7",
	-- Opacity of the accent when blended onto Normal's background for the
	-- line highlight (0 = invisible tint, 1 = solid accent).
	line_blend = 0.12,
	-- Extmark/sign priority. gitsigns uses 6, todo-comments 20. 10 puts the
	-- commit-lens marker above gitsigns' hunk sign but below todo.
	priority = 10,
	-- Skip buffers larger than this many lines. Blame is async (vim.system) so
	-- a slow blame never blocks the UI; this cap only guards pathological files
	-- (e.g. generated/minified). Big hand-written sources like Qualcomm
	-- camera-kernel's cam_ife_hw_mgr.c (~22k lines) must stay under it.
	max_lines = 100000,
	-- Skip filetypes (bigfile is snacks' large-file sentinel).
	skip_filetypes = { bigfile = true },
	-- Extra flags handed to every `git blame` (buffer marks AND tree refinement),
	-- spliced in right after "blame". These decide how aggressively a commit is
	-- credited for lines that were later reshaped:
	--   -w : ignore whitespace-only changes, so a line the commit introduced that
	--        was merely re-indented (or had trailing space touched) still counts.
	--   -M : detect moves *within a file*, so a block the commit added and that was
	--        later relocated elsewhere in the same file is still attributed to it.
	-- -C (detect copies/moves *across* files in the same commit) is deliberately
	-- left OUT of the default: it is markedly slower on large files and tends to
	-- over-attribute (crediting the commit for lines it only coincidentally
	-- matches). Users who want it can set `blame_args = { "-w", "-M", "-C" }`.
	-- These compose cleanly with `--line-porcelain --contents -` and do not change
	-- the porcelain header format parse_blame keys on.
	blame_args = { "-w", "-M" },
	-- Max concurrent `git blame` subprocesses when refining the tree file set.
	blame_jobs = 8,
	-- Max concurrent buffer-render `git blame` subprocesses. Kept separate from
	-- blame_jobs so a burst of buffer renders (session restore, :bufdo, a big
	-- quickfix populating windows) and the tree refinement don't contend for one
	-- budget. Per-buffer dedup already collapses the common double-fire; this caps
	-- the aggregate storm across many buffers opening at once.
	render_jobs = 8,
	-- Debounce (ms) for re-blaming a buffer after you edit it, so the marks
	-- (and the minimap) track your live changes without re-running on every
	-- keystroke.
	edit_debounce = 400,
	-- File-tree integration, handed to the tree-manager registry
	-- (lua/commit-lens/tree.lua). `managers = "auto"` drives every supported
	-- manager that is loaded; pass a list (e.g. { "nvim-tree" }) to restrict it,
	-- or {} to disable the tree layer. See that module for the adapter contract.
	tree = { managers = "auto" },
}

-- Private namespace: isolates our extmarks from gitsigns and everyone else.
M.ns = vim.api.nvim_create_namespace("commit_lens")

-- The chosen commit set: a map of full SHA -> true. Empty = inactive.
M.commits = {}
-- The last non-empty commit set + its display names, remembered across a clear so
-- :CommitLensToggle can flip the lens back on without re-picking. nil until the
-- first successful activate this session.
M.last_commits = nil
M.last_names = nil
-- Whether the lens is currently on. Gated so autocmds are cheap when off.
M.enabled = false
-- Monotonic version, bumped on every activate/clear. Any in-flight async blame
-- whose captured version != M.version is stale and its result is discarded.
M.version = 0
-- Repo toplevel of the active session (set on activate).
M.repo_root = nil
-- Absolute paths of files with surviving lines from the chosen commits
-- (blame-confirmed). Consumed by the nvim-tree decorator.
M.tree_files = {}
-- Absolute paths of every ancestor directory of a tree_files entry, so the
-- decorator can also mark collapsed parent directories (path "passthrough").
M.tree_dirs = {}

-- Per-buffer render cache: bufnr -> { version, tick, hits }. Lets repeated
-- BufWinEnter on an unchanged buffer skip the blame entirely.
local buf_cache = {}

-- Per-buffer in-flight blame claim: bufnr -> { version, tick }. Exactly one blame
-- is allowed in flight per (buffer, commit-set version, changedtick). This is what
-- collapses the BufReadPost+BufWinEnter double-fire on a single `:e` into one blame
-- (both would otherwise miss the still-empty cache and each spawn a subprocess).
-- Keyed by (version, tick), NOT tick alone: keying by tick would wrongly skip the
-- re-render after a re-activate at the same content tick, leaving the buffer
-- unmarked for the new commit set.
local pending = {}

-- Global cap on concurrent buffer-render blames (config.render_jobs). Renders past
-- the cap queue in blame_queue and drain as slots free, so a bulk open (session
-- restore, :bufdo, a big quickfix) can't spawn one `git blame` per buffer at once.
local blame_inflight = 0
local blame_queue = {} -- FIFO of { bufnr, version, tick } awaiting a slot

-- Per-buffer debounce timers for edit-triggered re-render (uv timers).
local edit_timers = {}

-- ---------------------------------------------------------------------------
-- Colour helpers (self-contained; mirrors the resolve+blend approach in
-- lua/lib/inactive_regions.lua so the tint adapts to the active theme).
-- ---------------------------------------------------------------------------

local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
end

local function blend(fg, bg, opacity)
	local fr, fgc, fb = hex_to_rgb(fg)
	local br, bgc, bb = hex_to_rgb(bg)
	local inv = 1 - opacity
	local r = math.floor(fr * opacity + br * inv + 0.5)
	local g = math.floor(fgc * opacity + bgc * inv + 0.5)
	local b = math.floor(fb * opacity + bb * inv + 0.5)
	return string.format("#%02x%02x%02x", math.min(255, r), math.min(255, g), math.min(255, b))
end

-- Resolve an attribute ("fg"/"bg") of a highlight group to a #rrggbb string,
-- following links, falling back to Normal and then to a sane default.
local function resolve_color(group, attr)
	local visited = {}
	local function resolve(name)
		if visited[name] then
			return nil
		end
		visited[name] = true
		local hl = vim.api.nvim_get_hl(0, { name = name })
		local val = hl[attr]
		if val then
			return type(val) == "string" and val or string.format("#%06x", val)
		end
		if hl.link then
			return resolve(hl.link)
		end
		return nil
	end
	local color = resolve(group)
	if not color and group ~= "Normal" then
		color = resolve_color("Normal", attr)
	end
	if not color then
		if attr == "fg" then
			color = vim.o.background == "dark" and "#ffffff" or "#000000"
		else
			color = vim.o.background == "dark" and "#000000" or "#ffffff"
		end
	end
	return color
end

-- (Re)define the highlight groups. Called on setup and on ColorScheme so the
-- blended tint tracks the active theme. `default = true` lets a theme override
-- win if the user defines these groups themselves.
local function create_highlights()
	local normal_bg = resolve_color("Normal", "bg")
	local line_bg = blend(M.config.accent, normal_bg, M.config.line_blend)
	-- Sign glyph in the accent colour.
	vim.api.nvim_set_hl(0, "CommitLensSign", { fg = M.config.accent, default = true })
	-- Whole-line background tint: "this code is historical, rendered apart".
	vim.api.nvim_set_hl(0, "CommitLensLine", { bg = line_bg, default = true })
	-- Optional line-number highlight to reinforce the marker.
	vim.api.nvim_set_hl(0, "CommitLensNr", { fg = M.config.accent, bg = line_bg, default = true })
end

-- ---------------------------------------------------------------------------
-- Git helpers
-- ---------------------------------------------------------------------------

-- Build a `git blame` argv, splicing M.config.blame_args (e.g. {-w,-M}) in right
-- after "blame". `head` is the fixed prefix ({ "git", "-C", dir, "blame" }); the
-- caller appends the tail (--line-porcelain, --contents, path, …). Keeps the two
-- blame call sites in lock-step on the configured flags.
local function blame_cmd(head, tail)
	local cmd = {}
	vim.list_extend(cmd, head)
	vim.list_extend(cmd, M.config.blame_args or {})
	vim.list_extend(cmd, tail)
	return cmd
end

-- Absolute directory of a buffer's file, or nil if it has none on disk.
local function buf_dir(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil
	end
	local dir = vim.fn.fnamemodify(name, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		return nil
	end
	return dir
end

-- Mark every ancestor directory of `path` (down to and including `base`).
local function add_ancestors(dirs, path, base)
	local dir = vim.fn.fnamemodify(path, ":h")
	while dir and dir ~= "" and dir ~= "/" and #dir >= #base do
		dirs[dir] = true
		if dir == base then
			break
		end
		local parent = vim.fn.fnamemodify(dir, ":h")
		if parent == dir then
			break
		end
		dir = parent
	end
end

-- Parse `git blame --line-porcelain` stdout into a sorted array of buffer line
-- numbers whose commit is in M.commits. Each group header is
-- "<sha> <orig> <final> [count]"; the 3rd field is the final-file line number.
local function parse_blame(stdout)
	local hits = {}
	for l in stdout:gmatch("[^\r\n]+") do
		local sha, final = l:match("^(%x+)%s+%d+%s+(%d+)")
		if sha and M.commits[sha] then
			hits[#hits + 1] = tonumber(final)
		end
	end
	table.sort(hits)
	return hits
end

-- Run `worker(item, done)` over `items` with at most `limit` concurrent, then
-- call `on_done`. `worker` must invoke its `done` callback exactly once.
local function run_pool(items, limit, worker, on_done)
	local n = #items
	if n == 0 then
		on_done()
		return
	end
	local i, finished = 0, 0
	local function launch()
		while i < n and (i - finished) < limit do
			i = i + 1
			worker(items[i], function()
				finished = finished + 1
				if finished == n then
					on_done()
				else
					launch()
				end
			end)
		end
	end
	launch()
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

-- Whether a buffer is eligible for the lens.
local function eligible(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end
	if M.config.skip_filetypes[vim.bo[bufnr].filetype] then
		return false
	end
	if vim.api.nvim_buf_line_count(bufnr) > M.config.max_lines then
		return false
	end
	return buf_dir(bufnr) ~= nil
end

-- Equal iff two sorted hit arrays are identical. Lets render() skip the whole
-- repaint (clear ns + reset extmarks + minimap refresh) when an edit didn't
-- change which lines belong to the chosen commits — the common case when you
-- edit lines the lens doesn't touch.
local function hits_equal(a, b)
	if not a or not b or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Fold the buffer's *live* commit-lens extmarks into contiguous blocks
-- ({ first = <lnum>, last = <lnum> }, 1-based inclusive). A block is a run of
-- consecutive marked lines, so a long marked region is one navigation stop, not
-- N, and the minimap draws one span instead of many.
--
-- Reads the extmark rows directly — which Neovim auto-shifts as you insert or
-- delete lines — rather than a snapshot taken at blame time. That is the whole
-- point: after an edit the marks are *already* in the right place, so callers
-- (]h/[h navigation, the neominimap handler) realign immediately at whatever
-- cadence they poll, without waiting on the debounced (up to 1.6s + blame)
-- re-render. The background re-blame still runs, but only to add/drop
-- membership (a just-typed line isn't the commit's); repositioning is free.
---@class CommitLens.Block
---@field first integer  -- first marked line (1-based, inclusive)
---@field last  integer  -- last marked line (1-based, inclusive)
---@param bufnr? integer  -- defaults to the current buffer
---@return CommitLens.Block[]
function M.get_blocks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return {}
	end
	-- nvim_buf_get_extmarks returns marks in ascending (row, col) order, so we
	-- can fold in one pass without sorting.
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, M.ns, 0, -1, {})
	local blocks = {}
	local prev_row
	for _, m in ipairs(marks) do
		local lnum = m[2] + 1 -- extmark row is 0-based; blocks are 1-based
		if lnum ~= prev_row then -- collapse any duplicate marks landing on one row
			local last = blocks[#blocks]
			if last and lnum == last.last + 1 then
				last.last = lnum
			else
				blocks[#blocks + 1] = { first = lnum, last = lnum }
			end
			prev_row = lnum
		end
	end
	return blocks
end

-- Notify neominimap (and any listener) that a buffer's lens marks changed.
local function fire_minimap_update(bufnr)
	pcall(vim.api.nvim_exec_autocmds, "User", {
		pattern = "CommitLensUpdate",
		data = { buffer = bufnr },
	})
end

-- Paint the computed hits onto a buffer: extmarks + minimap refresh. The
-- extmarks are the single source of truth for *where* the marks are — both
-- ]h/[h navigation and the neominimap handler fold them live via M.get_blocks,
-- so there is no separate block snapshot to keep in sync (and none to go stale
-- when you edit before the next blame lands).
local function apply_hits(bufnr, hits)
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
	for _, lnum in ipairs(hits) do
		-- lnum is 1-based; extmark row is 0-based.
		pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, lnum - 1, 0, {
			sign_text = M.config.sign_text,
			sign_hl_group = "CommitLensSign",
			number_hl_group = "CommitLensNr",
			line_hl_group = "CommitLensLine",
			priority = M.config.priority,
		})
	end
	fire_minimap_update(bufnr)
end

-- Async `git blame` of a buffer's working-tree contents; cb(hits) on the main
-- loop, or cb(nil) on failure.
local function blame_buffer(bufnr, cb)
	local dir = buf_dir(bufnr)
	if not dir then
		cb(nil)
		return
	end
	local file = vim.api.nvim_buf_get_name(bufnr)
	-- Feed the buffer via `--contents -` so line numbers match even with
	-- unsaved edits. Preserve the trailing newline (bo.eol) — without it git
	-- blames the last line on the 0-sha and the commit's final line is missed.
	local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	if vim.bo[bufnr].eol then
		contents = contents .. "\n"
	end
	vim.system(
		blame_cmd({ "git", "-C", dir, "blame" }, { "--line-porcelain", "--contents", "-", "--", file }),
		{ stdin = contents, text = true },
		function(res)
			local hits = (res.code == 0 and res.stdout) and parse_blame(res.stdout) or nil
			vim.schedule(function()
				cb(hits)
			end)
		end
	)
end

-- Launch the blame for a claimed (bufnr, ver, tick) and paint its result. Split
-- out of M.render so the concurrency queue can drain straight to it — re-entering
-- M.render on dequeue would just re-dedup against the still-live pending claim and
-- never launch. The caller MUST have set pending[bufnr] = { version, tick } first.
local function start_blame(bufnr, ver, tick)
	blame_inflight = blame_inflight + 1
	blame_buffer(bufnr, function(hits)
		blame_inflight = blame_inflight - 1

		-- Release our claim iff it is still ours. A newer claim (from a version
		-- bump, or a later tick) may already sit here; clobbering it would defeat
		-- the dedup and drop the tick-advance re-render below.
		local mine = pending[bufnr]
		if mine and mine.version == ver and mine.tick == tick then
			pending[bufnr] = nil
		end

		-- A slot just freed — drain the queue regardless of this buffer's fate.
		-- Re-validate each claim at dequeue: a version bump or a newer tick may
		-- have orphaned it (its buffer may even be gone).
		while #blame_queue > 0 and blame_inflight < M.config.render_jobs do
			local q = table.remove(blame_queue, 1)
			local claim = pending[q.bufnr]
			if
				claim
				and claim.version == q.ver
				and claim.tick == q.tick
				and M.version == q.ver
				and vim.api.nvim_buf_is_valid(q.bufnr)
			then
				start_blame(q.bufnr, q.ver, q.tick)
			end
		end

		-- Now this blame's own result. Discard if superseded or buffer gone.
		if M.version ~= ver or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		if not M.enabled then
			return
		end
		hits = hits or {}
		-- Short-circuit the repaint when the marked lines are unchanged. Compare
		-- against the LIVE cache, not a snapshot captured at render entry: with
		-- same-tick renders deduped, the only remaining overlap is different-tick
		-- blames, and a stale baseline could wrongly skip a needed repaint.
		-- buf_cache[bufnr].hits always mirrors the currently-painted extmarks for
		-- this version, so it is the correct baseline. Extmarks auto-shift with
		-- edits, so identical hit line numbers are already in the right place.
		local live = buf_cache[bufnr]
		if not (live and live.version == ver and hits_equal(live.hits, hits)) then
			apply_hits(bufnr, hits)
		end
		buf_cache[bufnr] = { version = ver, tick = tick, hits = hits }

		-- The buffer changed while we were blaming, so these hits describe stale
		-- content. Re-render once for the current tick (pending was cleared above,
		-- so this relaunches; it self-dedups if a blame for that tick is pending).
		if vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
			M.render(bufnr)
		end
	end)
end

-- Render (or clear) the lens for one buffer. Async + cached + in-flight deduped.
---@param bufnr? integer  -- defaults to the current buffer
function M.render(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not M.enabled or not next(M.commits) or not eligible(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
		fire_minimap_update(bufnr)
		buf_cache[bufnr] = nil
		pending[bufnr] = nil
		return
	end
	local ver = M.version
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	local cache = buf_cache[bufnr]
	if cache and cache.version == ver and cache.tick == tick then
		return -- already rendered for this exact (commit set, buffer content)
	end
	-- Dedup: a blame for this exact (version, tick) is already in flight or queued.
	-- Collapses the BufReadPost+BufWinEnter double-fire on `:e`, and coalesces an
	-- edit-debounced render with a buffer-enter render landing at the same tick.
	local p = pending[bufnr]
	if p and p.version == ver and p.tick == tick then
		return
	end
	-- Claim the slot before launching OR queuing, so duplicates dedup even while a
	-- render waits for a free slot.
	pending[bufnr] = { version = ver, tick = tick }
	if blame_inflight >= M.config.render_jobs then
		blame_queue[#blame_queue + 1] = { bufnr = bufnr, ver = ver, tick = tick }
	else
		start_blame(bufnr, ver, tick)
	end
end

-- Debounced re-render after edits. Editing shifts line numbers, so the cached
-- blocks (and thus the minimap marks) go stale; re-blame after a quiet period
-- so the magenta marks realign and any lines you just added drop out (they
-- belong to the working tree, not the chosen commits — gitsigns' green covers
-- them instead). Coalesces bursts of keystrokes into one blame.
local function debounce_render(bufnr)
	if not M.enabled then
		return
	end
	local timer = edit_timers[bufnr]
	if not timer then
		timer = vim.uv.new_timer()
		edit_timers[bufnr] = timer
	end
	-- Adaptive debounce: blame cost grows with file size, so wait longer before
	-- re-blaming a big file (fewer wasted blames mid-typing). Small files stay
	-- snappy. ~+1 base-delay per 5k lines, capped at 4×.
	local lines = vim.api.nvim_buf_line_count(bufnr)
	local factor = math.min(4, 1 + math.floor(lines / 5000))
	timer:stop()
	timer:start(
		M.config.edit_debounce * factor,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(bufnr) then
				M.render(bufnr)
			end
		end)
	)
end

-- Re-render every loaded buffer (used when the commit set changes).
local function render_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			M.render(bufnr)
		end
	end
end

-- Clear the lens everywhere.
local function clear_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
			if vim.api.nvim_buf_is_loaded(bufnr) then
				-- Extmarks gone → M.get_blocks now returns {}; tell the minimap.
				fire_minimap_update(bufnr)
			end
		end
	end
	buf_cache = {}
end

-- Ask every configured file manager to re-render so its commit-lens adapter
-- picks up the new tree_files/tree_dirs. Delegated to the tree-manager registry
-- (lua/commit-lens/tree.lua), which fans out to each loaded manager's adapter.
-- No-op if none is loaded.
local function reload_tree()
	pcall(function()
		require("commit-lens.tree").refresh()
	end)
end

-- Candidate files the chosen commits touched: union of `git show --name-only`
-- across M.commits (robust under non-linear history). Fully async (never blocks
-- the UI, matching the rest of the plugin): resolves the repo toplevel, then fans
-- `git show` across the commits bounded by config.blame_jobs, and calls
-- cb(rel, root) on the main loop. These are candidates only; blame decides which
-- actually survive. Defined here (after run_pool) so it can use the pool.
local function candidate_files(cwd, cb)
	vim.system({ "git", "-C", cwd, "rev-parse", "--show-toplevel" }, { text = true }, function(rp)
		vim.schedule(function()
			local root = (rp.code == 0 and rp.stdout) and (rp.stdout:gsub("%s+$", "")) or nil
			if root == "" then
				root = nil
			end
			-- Snapshot the commit set into a stable job list.
			local shas = {}
			for sha in pairs(M.commits) do
				shas[#shas + 1] = sha
			end
			local seen, rel = {}, {}
			run_pool(shas, M.config.blame_jobs, function(sha, done)
				vim.system(
					{ "git", "-C", cwd, "show", "--name-only", "--pretty=format:", sha },
					{ text = true },
					function(res)
						vim.schedule(function()
							if res.code == 0 and res.stdout then
								for f in res.stdout:gmatch("[^\r\n]+") do
									if f ~= "" and not seen[f] then
										seen[f] = true
										rel[#rel + 1] = f
									end
								end
							end
							done()
						end)
					end
				)
			end, function()
				table.sort(rel)
				cb(rel, root)
			end)
		end)
	end)
end

-- Refine the tree file set with blame: keep only candidates that still have a
-- surviving line from the chosen commits (same "口径" as the buffer marks). Fully
-- async: gathers candidates via candidate_files, then blames them bounded to
-- config.blame_jobs, then reloads the tree once. Every stage is version-gated so a
-- newer activate/clear supersedes it cleanly.
local function rebuild_tree_sets(cwd)
	local ver = M.version
	candidate_files(cwd, function(rel, root)
		-- Superseded while gathering candidates → drop the whole rebuild.
		if M.version ~= ver then
			return
		end
		M.repo_root = root
		local base = root or "."
		M.tree_files = {}
		M.tree_dirs = {}
		run_pool(rel, M.config.blame_jobs, function(f, done)
			vim.system(
				blame_cmd({ "git", "-C", base, "blame" }, { "--line-porcelain", "--", f }),
				{ text = true },
				function(res)
					vim.schedule(function()
						-- Skip if superseded by a newer activate/clear.
						if M.version == ver and res.code == 0 and res.stdout then
							for l in res.stdout:gmatch("[^\r\n]+") do
								local sha = l:match("^(%x+)%s+%d+%s+%d+")
								if sha and M.commits[sha] then
									local path = base .. "/" .. f
									M.tree_files[path] = true
									add_ancestors(M.tree_dirs, path, base)
									break
								end
							end
						end
						done()
					end)
				end
			)
		end, function()
			if M.version == ver then
				reload_tree()
			end
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Navigation: jump between commit-lens blocks in the current buffer.
-- ---------------------------------------------------------------------------

local function jump(direction)
	local bufnr = vim.api.nvim_get_current_buf()
	local blocks = M.get_blocks(bufnr)
	if not blocks or #blocks == 0 then
		vim.notify("commit-lens: no marked lines in this buffer", vim.log.levels.INFO)
		return
	end
	local cur = vim.api.nvim_win_get_cursor(0)[1]
	local target
	if direction > 0 then
		-- Next block whose start is below the cursor. If the cursor sits inside
		-- a block, that block's own start (== cur) is skipped, so we advance to
		-- the following region rather than jumping within the current one.
		for _, b in ipairs(blocks) do
			if b.first > cur then
				target = b.first
				break
			end
		end
		target = target or blocks[1].first -- wrap to first
	else
		-- Previous block start strictly above the cursor. Landing anywhere
		-- inside a block (cur > b.first) still steps to the prior region.
		for i = #blocks, 1, -1 do
			if blocks[i].first < cur then
				target = blocks[i].first
				break
			end
		end
		target = target or blocks[#blocks].first -- wrap to last
	end
	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd("normal! zz")
end

function M.goto_next()
	jump(1)
end

function M.goto_prev()
	jump(-1)
end

-- ---------------------------------------------------------------------------
-- Activation
-- ---------------------------------------------------------------------------

-- Monotonic activation-attempt counter, bumped SYNCHRONOUSLY at the start of every
-- activate()/clear(). It lets an in-flight async rev-resolution notice that a newer
-- :CommitLens (or a clear) superseded it before it committed, and bail. This is a
-- DIFFERENT token from M.version: M.version guards in-flight *blames* and is bumped
-- only at the commit point (after resolution succeeds), so a failed or superseded
-- resolution never tears down the currently-rendered session.
local activate_seq = 0

-- Commit point: publish a resolved commit set as the active lens session. Called
-- once resolution has produced a non-empty `set` (SHA -> true) with display
-- `names`. Bumping M.version HERE (not at activate entry) is deliberate — see
-- activate_seq above. Also remembers the set for :CommitLensToggle.
local function commit_set(set, names, cwd)
	M.commits = set
	M.last_commits = set
	M.last_names = names
	M.enabled = true
	M.version = M.version + 1 -- invalidate caches + supersede in-flight blames
	buf_cache = {}
	pending = {}
	render_all()
	rebuild_tree_sets(cwd)
	vim.notify("commit-lens: on for " .. table.concat(names, ", "), vim.log.levels.INFO)
end

-- Turn the lens on for a list of user-typed revs. Fully async (matching the rest
-- of the plugin — never blocks the UI): each rev is resolved to a full SHA via an
-- async `git rev-parse`, bounded by config.blame_jobs. Only once ALL revs resolve
-- do we commit the new session, so a second :CommitLens issued mid-resolution
-- supersedes the first deterministically (via activate_seq).
local function activate(revs)
	local cwd = buf_dir(vim.api.nvim_get_current_buf()) or vim.fn.getcwd()
	activate_seq = activate_seq + 1
	local seq = activate_seq

	-- Resolve by index so notify order matches the user's input order.
	local resolved = {}
	local idxs = {}
	for i = 1, #revs do
		idxs[i] = i
	end

	run_pool(idxs, M.config.blame_jobs, function(i, done)
		vim.system(
			{ "git", "-C", cwd, "rev-parse", "--verify", "--quiet", revs[i] .. "^{commit}" },
			{ text = true },
			function(res)
				vim.schedule(function()
					-- Record only if we are still the current attempt (else another
					-- activate/clear already superseded us; on_done will bail).
					if seq == activate_seq and res.code == 0 and res.stdout then
						local sha = res.stdout:match("^(%x+)")
						if sha and sha ~= "" then
							resolved[i] = sha
						end
					end
					done()
				end)
			end
		)
	end, function()
		-- Superseded by a newer activate()/clear() while resolving → do nothing,
		-- and emit no warnings (the winning attempt owns all user-facing output).
		if seq ~= activate_seq then
			return
		end
		local set, names = {}, {}
		for i = 1, #revs do
			if resolved[i] then
				set[resolved[i]] = true
				names[#names + 1] = revs[i]
			else
				vim.notify("commit-lens: cannot resolve rev '" .. revs[i] .. "'", vim.log.levels.WARN)
			end
		end
		if not next(set) then
			vim.notify("commit-lens: no valid commits given", vim.log.levels.ERROR)
			return -- previous session, if any, left intact
		end
		commit_set(set, names, cwd)
	end)
end

function M.clear()
	M.commits = {}
	M.enabled = false
	M.version = M.version + 1
	activate_seq = activate_seq + 1 -- cancel any in-flight rev-resolution (else it
	-- would re-enable the lens right after this clear)
	M.tree_files = {}
	M.tree_dirs = {}
	-- Stop + close any live edit-debounce timers. Without this they idle-spin (each
	-- fires once more and no-ops on the M.enabled guard) and leak the uv handle
	-- until the buffer is deleted.
	for bufnr, timer in pairs(edit_timers) do
		timer:stop()
		timer:close()
		edit_timers[bufnr] = nil
	end
	pending = {}
	clear_all()
	reload_tree()
	vim.notify("commit-lens: off", vim.log.levels.INFO)
end

-- Toggle the lens: off if currently on; else re-activate the last chosen set (no
-- re-resolution needed — those SHAs are already full and valid); else, if nothing
-- was ever chosen this session, open the picker so the key is never a dead end.
function M.toggle()
	if M.enabled then
		M.clear()
		return
	end
	if M.last_commits and next(M.last_commits) then
		local cwd = buf_dir(vim.api.nvim_get_current_buf()) or vim.fn.getcwd()
		-- Copy the set so the remembered table and the live one don't alias.
		local set = {}
		for sha in pairs(M.last_commits) do
			set[sha] = true
		end
		activate_seq = activate_seq + 1 -- align with the activate/clear discipline
		commit_set(set, vim.deepcopy(M.last_names or {}), cwd)
		return
	end
	M.pick_commits()
end

-- Open a fzf-lua git_commits multi-select; chosen commits activate the lens.
-- Exposed on M so M.toggle can fall back to it (and it's defined after toggle).
function M.pick_commits()
	local ok, fzf = pcall(require, "fzf-lua")
	if not ok then
		vim.notify("commit-lens: fzf-lua not available; pass SHAs directly, e.g. :CommitLens <sha>", vim.log.levels.ERROR)
		return
	end
	fzf.git_commits({
		prompt = "CommitLens> ",
		-- git_commits defaults to single-select (`--no-multi`). Negate that
		-- (fzf-lua drops any fzf_opts flag whose value is false) and turn on
		-- `--multi` so <Tab> toggles-selects several commits.
		fzf_opts = { ["--no-multi"] = false, ["--multi"] = true },
		actions = {
			-- Override the provider's default enter action (git_checkout!) with
			-- our own. `default` takes precedence over `enter` in fzf-lua, so
			-- pressing <CR> here activates the lens instead of checking out.
			["default"] = function(selected)
				local revs = {}
				for _, line in ipairs(selected or {}) do
					-- git_commits entries start with the short SHA; take the
					-- first hex token (strip any ANSI colour codes first).
					local clean = line:gsub("\27%[[%d;]*m", "")
					local sha = clean:match("(%x%x%x%x%x%x%x+)")
					if sha then
						revs[#revs + 1] = sha
					end
				end
				if next(revs) then
					activate(revs)
				else
					vim.notify("commit-lens: no commit selected", vim.log.levels.WARN)
				end
			end,
		},
	})
end

-- Show the blame-confirmed touched files (same set the tree marks). Uses
-- fzf-lua when available (preview + <CR> to open + <C-q> to send to quickfix),
-- and falls back to the quickfix list otherwise.
function M.files()
	if not M.enabled or not next(M.tree_files) then
		vim.notify("commit-lens: no touched files yet (run :CommitLens first)", vim.log.levels.WARN)
		return
	end
	local root = M.repo_root or "."
	-- Collect repo-relative paths (sorted) so fzf renders them cleanly and
	-- resolves them against cwd for preview/open.
	local rel = {}
	for p in pairs(M.tree_files) do
		local r = p:sub(#root + 2) -- strip "root/"
		rel[#rel + 1] = (r ~= "" and r) or p
	end
	table.sort(rel)

	local ok, fzf = pcall(require, "fzf-lua")
	if ok then
		fzf.fzf_exec(rel, {
			prompt = "CommitLensFiles> ",
			cwd = root,
			previewer = "builtin",
			file_icons = true,
			color_icons = true,
			-- Standard file actions: <CR> opens one, multi-select → quickfix,
			-- plus fzf-lua's default split/vsplit/tab/quickfix binds.
			actions = fzf.defaults.actions.files,
		})
		return
	end

	-- Fallback: quickfix list.
	local items = {}
	for _, r in ipairs(rel) do
		items[#items + 1] = { filename = root .. "/" .. r, lnum = 1, text = r }
	end
	vim.fn.setqflist({}, " ", { title = "commit-lens: touched files", items = items })
	vim.cmd("botright copen")
end

-- ---------------------------------------------------------------------------
-- Setup: highlights, commands, keymaps, autocmds.
-- ---------------------------------------------------------------------------

---@param opts? CommitLens.Config  -- partial; deep-merged over the defaults
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	create_highlights()

	-- Bring up the tree-manager registry: register builtin adapters, resolve
	-- "auto" vs an explicit manager list, and let self-wiring adapters attach.
	require("commit-lens.tree").setup(M.config.tree)

	vim.api.nvim_create_user_command("CommitLens", function(cmd)
		if cmd.args and cmd.args ~= "" then
			activate(vim.split(cmd.args, "%s+", { trimempty = true }))
		else
			M.pick_commits()
		end
	end, { nargs = "*", desc = "commit-lens: mark lines from commit(s) (no args = fzf pick)" })

	vim.api.nvim_create_user_command("CommitLensClear", function()
		M.clear()
	end, { desc = "commit-lens: clear the lens" })

	vim.api.nvim_create_user_command("CommitLensToggle", function()
		M.toggle()
	end, { desc = "commit-lens: toggle the lens (re-uses last set, else picks)" })

	vim.api.nvim_create_user_command("CommitLensFiles", function()
		M.files()
	end, { desc = "commit-lens: list touched files (fzf, quickfix fallback)" })

	-- ]h / [h jump between marked blocks (no-op notify when none).
	vim.keymap.set("n", "]h", M.goto_next, { silent = true, desc = "Next commit-lens block" })
	vim.keymap.set("n", "[h", M.goto_prev, { silent = true, desc = "Prev commit-lens block" })

	local aug = vim.api.nvim_create_augroup("CommitLens", { clear = true })
	-- Re-render on entering/opening a buffer while the lens is on. Cheap when
	-- the buffer is unchanged (cache hit) or the lens is off.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		group = aug,
		callback = function(args)
			if M.enabled then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(args.buf) then
						M.render(args.buf)
					end
				end)
			end
		end,
	})
	-- Re-blame (debounced) after edits so the marks + minimap track your live
	-- changes and stay aligned with gitsigns' green/red.
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = aug,
		callback = function(args)
			if M.enabled and eligible(args.buf) then
				debounce_render(args.buf)
			end
		end,
	})
	-- Drop cache + timer + in-flight claim for deleted buffers.
	vim.api.nvim_create_autocmd("BufDelete", {
		group = aug,
		callback = function(args)
			buf_cache[args.buf] = nil
			pending[args.buf] = nil
			local timer = edit_timers[args.buf]
			if timer then
				timer:stop()
				timer:close()
				edit_timers[args.buf] = nil
			end
		end,
	})
	-- Rebuild the blended tint when the colorscheme changes.
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = aug,
		callback = create_highlights,
	})
end

return M
