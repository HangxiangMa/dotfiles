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

-- Default config; overridable via setup(opts).
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
	-- Max concurrent `git blame` subprocesses when refining the tree file set.
	blame_jobs = 8,
	-- Debounce (ms) for re-blaming a buffer after you edit it, so the marks
	-- (and the minimap) track your live changes without re-running on every
	-- keystroke.
	edit_debounce = 400,
}

-- Private namespace: isolates our extmarks from gitsigns and everyone else.
M.ns = vim.api.nvim_create_namespace("commit_lens")

-- The chosen commit set: a map of full SHA -> true. Empty = inactive.
M.commits = {}
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

-- Normalize a rev the user typed (short SHA, HEAD~2, tag…) to a full SHA so
-- set-membership against blame output is exact. Returns nil on failure.
local function full_sha(rev, cwd)
	local out = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--verify", "--quiet", rev .. "^{commit}" })
	if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
		return nil
	end
	return out[1]
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

-- Candidate files the chosen commits touched: union of `git show --name-only`
-- across M.commits (robust under non-linear history). Returns rel-path list +
-- repo root. These are candidates only; blame decides which actually survive.
local function candidate_files(cwd)
	local root = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })[1]
	local seen, rel = {}, {}
	for sha in pairs(M.commits) do
		local out = vim.fn.systemlist({ "git", "-C", cwd, "show", "--name-only", "--pretty=format:", sha })
		if vim.v.shell_error == 0 then
			for _, f in ipairs(out) do
				if f ~= "" and not seen[f] then
					seen[f] = true
					rel[#rel + 1] = f
				end
			end
		end
	end
	table.sort(rel)
	return rel, root
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
		{ "git", "-C", dir, "blame", "--line-porcelain", "--contents", "-", "--", file },
		{ stdin = contents, text = true },
		function(res)
			local hits = (res.code == 0 and res.stdout) and parse_blame(res.stdout) or nil
			vim.schedule(function()
				cb(hits)
			end)
		end
	)
end

-- Render (or clear) the lens for one buffer. Async + cached.
function M.render(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not M.enabled or not next(M.commits) or not eligible(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
		fire_minimap_update(bufnr)
		buf_cache[bufnr] = nil
		return
	end
	local ver = M.version
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	local cache = buf_cache[bufnr]
	if cache and cache.version == ver and cache.tick == tick then
		return -- already rendered for this exact (commit set, buffer content)
	end
	blame_buffer(bufnr, function(hits)
		-- Discard if superseded (new activate/clear) or buffer gone.
		if M.version ~= ver or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		if not M.enabled then
			return
		end
		hits = hits or {}
		-- Skip the repaint entirely when the marked lines are unchanged from the
		-- last render for this same commit-set version. Extmarks auto-shift with
		-- edits, so if the hit line numbers are identical they're already in the
		-- right place — no clear, no re-set, no minimap refresh. This is the
		-- hot path while you type in an unrelated part of the file.
		if cache and cache.version == ver and hits_equal(cache.hits, hits) then
			buf_cache[bufnr] = { version = ver, tick = tick, hits = hits }
			return
		end
		apply_hits(bufnr, hits)
		buf_cache[bufnr] = { version = ver, tick = tick, hits = hits }
	end)
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

-- Ask nvim-tree to re-render so its commit-lens decorator picks up the new
-- tree_files/tree_dirs. No-op if nvim-tree isn't loaded.
local function reload_tree()
	pcall(function()
		require("nvim-tree.api").tree.reload()
	end)
end

-- Refine the tree file set with blame: keep only candidates that still have a
-- surviving line from the chosen commits (same "口径" as the buffer marks).
-- Runs async, bounded to config.blame_jobs, then reloads the tree once.
local function rebuild_tree_sets(cwd)
	local rel, root = candidate_files(cwd)
	M.repo_root = root
	local base = root or "."
	M.tree_files = {}
	M.tree_dirs = {}
	local ver = M.version
	run_pool(rel, M.config.blame_jobs, function(f, done)
		vim.system(
			{ "git", "-C", base, "blame", "--line-porcelain", "--", f },
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

-- Turn the lens on for a list of user-typed revs (resolved to full SHAs).
local function activate(revs)
	local cwd = buf_dir(vim.api.nvim_get_current_buf()) or vim.fn.getcwd()
	local set, names = {}, {}
	for _, rev in ipairs(revs) do
		local sha = full_sha(rev, cwd)
		if sha then
			set[sha] = true
			names[#names + 1] = rev
		else
			vim.notify("commit-lens: cannot resolve rev '" .. rev .. "'", vim.log.levels.WARN)
		end
	end
	if not next(set) then
		vim.notify("commit-lens: no valid commits given", vim.log.levels.ERROR)
		return
	end
	M.commits = set
	M.enabled = true
	M.version = M.version + 1 -- invalidate caches + supersede in-flight blames
	buf_cache = {}
	render_all()
	rebuild_tree_sets(cwd)
	vim.notify("commit-lens: on for " .. table.concat(names, ", "), vim.log.levels.INFO)
end

function M.clear()
	M.commits = {}
	M.enabled = false
	M.version = M.version + 1
	M.tree_files = {}
	M.tree_dirs = {}
	clear_all()
	reload_tree()
	vim.notify("commit-lens: off", vim.log.levels.INFO)
end

-- Open a fzf-lua git_commits multi-select; chosen commits activate the lens.
local function pick_commits()
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

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	create_highlights()

	vim.api.nvim_create_user_command("CommitLens", function(cmd)
		if cmd.args and cmd.args ~= "" then
			activate(vim.split(cmd.args, "%s+", { trimempty = true }))
		else
			pick_commits()
		end
	end, { nargs = "*", desc = "commit-lens: mark lines from commit(s) (no args = fzf pick)" })

	vim.api.nvim_create_user_command("CommitLensClear", function()
		M.clear()
	end, { desc = "commit-lens: clear the lens" })

	vim.api.nvim_create_user_command("CommitLensFiles", function()
		M.files()
	end, { desc = "commit-lens: list touched files in quickfix" })

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
	-- Drop cache + timer for deleted buffers.
	vim.api.nvim_create_autocmd("BufDelete", {
		group = aug,
		callback = function(args)
			buf_cache[args.buf] = nil
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
