-- virtcolumn: draw a character as the colorcolumn instead of a solid block.
--
-- Vendored from https://github.com/xiyaowong/virtcolumn.nvim (MIT) and extended
-- locally with two changes upstream lacks:
--
--   1. Language/formatter recognition. Upstream derives the guide column ONLY
--      from 'colorcolumn'/'textwidth'. When a buffer sets neither, we look up
--      the project's configured line length from the language's formatter config
--      (.clang-format ColumnLimit, rustfmt max_width, black/ruff/flake8 for
--      Python) so the guide "just works" without setting cc per project.
--      (Neovim already maps .editorconfig max_line_length -> textwidth, so
--      editorconfig is handled by the existing textwidth path.)
--
--   2. Fix for upstream issue #12: the guide's extmark used priority 10, which
--      draws it ON TOP of LSP inlay-hint virt_text and hides characters. The
--      guide should sit on the lowest layer, so the default is now 1.
--
-- Explicit 'colorcolumn'/'textwidth' always wins over autodetection.

local api, fn = vim.api, vim.fn

local M = {}

-- Config; overridable via setup(opts). The legacy globals vim.g.virtcolumn_char
-- and vim.g.virtcolumn_priority still take precedence if set, for muscle memory.
M.config = {
	char = "▕",
	priority = 1, -- issue #12: keep the guide under inlay-hint / diagnostic virt_text
	autodetect = true, -- read formatter configs for c/cpp/rust/python (see DETECTORS)
	-- Per-language fallback line length, used when autodetect is on but NO
	-- formatter config is found for the buffer. These are each tool's own
	-- default: clang-format's LLVM style = 80, rustfmt = 100, black = 88. Set an
	-- entry to 0 (or false) to draw nothing for that language without a config.
	defaults = {
		clang = 80,
		rust = 100,
		python = 88,
	},
}

local NS = api.nvim_create_namespace("virtcolumn")

---------------------------------------------------------------------------
-- Formatter-config detection
--
-- Each detector receives the directory of the current buffer and walks upward
-- looking for the language's formatter config, returning a line length or nil.
---------------------------------------------------------------------------

---@param dir string
---@param names string[]
---@return string|nil  path of the nearest matching file, searching upward
local function first_upward(dir, names)
	local found = vim.fs.find(names, { upward = true, path = dir, type = "file" })
	return found[1]
end

---Return the first number matched by any pattern across the file's lines.
---@param path string
---@param patterns string[]  lua patterns with a single (%d+) capture
---@return number|nil
local function match_number_in_file(path, patterns)
	local ok, lines = pcall(fn.readfile, path)
	if not ok then
		return nil
	end
	for _, line in ipairs(lines) do
		for _, pat in ipairs(patterns) do
			local n = line:match(pat)
			if n then
				return tonumber(n)
			end
		end
	end
	return nil
end

-- The configured per-language fallback, normalized: a positive number or nil.
-- 0 / false means "no guide for this language without a config".
---@param key string  key into M.config.defaults
---@return number|nil
local function lang_default(key)
	local d = M.config.defaults and M.config.defaults[key]
	if type(d) == "number" and d > 0 then
		return d
	end
	return nil
end

-- C-family: .clang-format's `ColumnLimit`. An explicit `ColumnLimit: 0` means
-- "no limit" -> draw nothing (respected). With no config, fall back to the
-- configured clang default (clang-format's LLVM base style uses 80).
local function detect_clang(dir)
	local cfg = first_upward(dir, { ".clang-format", "_clang-format" })
	if not cfg then
		return lang_default("clang")
	end
	local n = match_number_in_file(cfg, { "^%s*ColumnLimit%s*:%s*(%d+)" })
	if n then
		-- Key present: honour it exactly, including 0 = "no limit" -> nil.
		return n > 0 and n or nil
	end
	-- Config exists but no ColumnLimit key: fall back to the default.
	return lang_default("clang")
end

-- Rust: rustfmt.toml's `max_width` (rustfmt's default is 100). With no config,
-- fall back to the configured rust default.
local function detect_rust(dir)
	local cfg = first_upward(dir, { "rustfmt.toml", ".rustfmt.toml" })
	if cfg then
		return match_number_in_file(cfg, { "^%s*max_width%s*=%s*(%d+)" }) or lang_default("rust")
	end
	return lang_default("rust")
end

-- Python: black/ruff `line-length` and isort `line_length` in pyproject.toml,
-- else flake8/pycodestyle `max-line-length` in .flake8/setup.cfg/tox.ini. With
-- no config, fall back to the configured python default (black's is 88).
local function detect_python(dir)
	local py = first_upward(dir, { "pyproject.toml" })
	if py then
		local n = match_number_in_file(py, {
			"^%s*line%-length%s*=%s*(%d+)",
			"^%s*line_length%s*=%s*(%d+)",
		})
		if n then
			return n
		end
	end
	local ini = first_upward(dir, { ".flake8", "setup.cfg", "tox.ini" })
	if ini then
		local n = match_number_in_file(ini, {
			"^%s*max%-line%-length%s*=%s*(%d+)",
			"^%s*max_line_length%s*=%s*(%d+)",
		})
		if n then
			return n
		end
	end
	return lang_default("python")
end

-- Filetype -> detector. Restricted to filetypes that use these configs by
-- convention; clang-format also supports Java/JS/C#, but those communities use
-- other formatters, so we don't bind them here to avoid false positives.
local DETECTORS = {
	c = detect_clang,
	cpp = detect_clang,
	objc = detect_clang,
	objcpp = detect_clang,
	cuda = detect_clang,
	proto = detect_clang,
	rust = detect_rust,
	python = detect_python,
}

-- Detect (and cache per-buffer) the guide column for `buf`. The cache is
-- invalidated on FileType/BufRead in refresh(), the only events that change the
-- filetype or file path this depends on. `false` = "computed, none found".
---@param buf integer
---@return number|nil
local function detect_column(buf)
	if not M.config.autodetect then
		return nil
	end
	local cached = vim.b[buf].virtcolumn_detected
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local result
	local detector = DETECTORS[vim.bo[buf].filetype]
	if detector then
		local name = api.nvim_buf_get_name(buf)
		local dir = (name ~= "" and vim.fs.dirname(name)) or fn.getcwd()
		local ok, val = pcall(detector, dir)
		if ok then
			result = val
		end
	end
	vim.b[buf].virtcolumn_detected = result or false
	return result
end

---------------------------------------------------------------------------
-- Rendering (upstream logic, unchanged except where noted)
---------------------------------------------------------------------------

---@class WinContext
---@field textoff integer
---@field topline integer
---@field botline integer
---@field width integer
---@field height integer
---@field leftcol integer
---@field winnr integer

---@return WinContext
local function get_win_context()
	local info = fn.getwininfo(api.nvim_get_current_win())[1]
	local view = fn.winsaveview()
	return vim.tbl_extend("force", info, view)
end

---@param cc string
---@return number[]
local function parse_items(cc)
	local textwidth = vim.bo.textwidth
	---@type number[]
	local items = {}
	for _, c in ipairs(vim.split(cc, ",")) do
		local item
		if c and c ~= "" then
			if vim.startswith(c, "+") then
				if textwidth ~= 0 then
					item = textwidth + tonumber(c:sub(2))
				end
			elseif vim.startswith(c, "-") then -- upstream tested `cc` here (bug); use the item `c`
				if textwidth ~= 0 then
					item = textwidth - tonumber(c:sub(2))
				end
			else
				item = tonumber(c)
			end
		end
		if item and item > 0 then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return a > b
	end)
	return items
end

-- Return true if display cell `col` of `line` is "empty" -- i.e. the guide can
-- be drawn there without covering real text. That is the case when `col` is
-- past the line's rendered width or sits on whitespace. Unlike a byte-offset
-- check, this expands tabs to the tabstop and counts wide (e.g. CJK) characters
-- as their real 2-cell width, so the guide (which is placed by SCREEN column)
-- is never laid on top of a real glyph that a byte index would have missed.
--
-- This is the fix for the truncation of tab-indented lines and lines with CJK
-- text: the guide's extmark occupies a screen cell and always wins that cell
-- over the buffer's real text, so the only way not to truncate is to not draw
-- when a real glyph already lives there.
---@param line string  the (tab-containing) rendered line
---@param col integer  1-indexed screen/display column of the guide
---@param tabstop integer  buffer 'tabstop' (>= 1)
---@return boolean
local function is_display_cell_empty(line, col, tabstop)
	local dcol = 0 -- display cells consumed so far; next cell is dcol + 1
	for _, ch in ipairs(fn.split(line, "\\zs")) do
		local w
		if ch == "\t" then
			w = tabstop - (dcol % tabstop) -- tab advances to the next tabstop
		else
			w = fn.strwidth(ch) -- 1 for ASCII, 2 for wide (CJK) chars
		end
		if col <= dcol + w then
			-- `col` falls within this character's cells [dcol+1, dcol+w].
			return ch == "\t" or ch == " "
		end
		dcol = dcol + w
	end
	-- `col` is past the end of the rendered line -> nothing there.
	return true
end

local function get_buf_lines(buf, start, end_)
	local rep = string.rep(" ", vim.opt.tabstop:get())
	local lines = api.nvim_buf_get_lines(buf, start, end_, false)
	local marks = vim.tbl_filter(function(v)
		return v[4].virt_text_pos == "inline"
	end, api.nvim_buf_get_extmarks(buf, -1, { start, 0 }, { end_, 0 }, {
		details = true,
		type = "virt_text",
	}))

	local lines_offset = {}
	local row, col, offset, line, line_idx, text
	for _, mark in ipairs(marks) do
		row = mark[2]
		line_idx = row - start + 1
		line = lines[line_idx]
		if line then
			line = line:gsub("\t", rep)
			offset = lines_offset[row] or 0
			col = mark[3] + offset
			text = table.concat(
				vim.tbl_map(function(v)
					return v[1]
				end, mark[4].virt_text),
				""
			)
			line = line:sub(1, col) .. text .. line:sub(col + 1)
			lines[line_idx] = line
			lines_offset[row] = offset + #text
		end
	end
	return lines
end

local function _refresh()
	local curbuf = api.nvim_get_current_buf()
	if not api.nvim_buf_is_loaded(curbuf) then
		return
	end

	-- Cache the resolved columns on the BUFFER, not the window: the guide
	-- depends on filetype/textwidth/detection (all buffer-local). Upstream also
	-- read a window-local copy, but an empty {} left on the window by a
	-- previously-shown buffer is truthy and would suppress detection here. A
	-- window-local `cc` that differs is still honoured by the local_cc branch.
	local items = vim.b.virtcolumn_items
	local local_cc = api.nvim_get_option_value("cc", { scope = "local" })
	-- Recompute when we have no cached columns yet (nil, or an empty {} that
	-- means "nothing found — keep trying cheaply") or when the user just set a
	-- window-local cc. `virtcolumn_source` records whether the cached columns
	-- came from an explicit cc/tw or from detection, so a later FileType event
	-- can re-detect (see refresh) without discarding an explicit setting.
	if not items or #items == 0 or local_cc ~= "" then
		items = parse_items(local_cc)
		if #items > 0 then
			vim.b.virtcolumn_source = "explicit"
		else
			-- No explicit colorcolumn/textwidth: fall back to the language's
			-- configured line length, if we can detect one.
			local detected = detect_column(curbuf)
			if detected then
				items = { detected }
			end
			vim.b.virtcolumn_source = "detected"
		end
		vim.b.virtcolumn_last_cc = local_cc
		api.nvim_set_option_value("cc", "", { scope = "local" })
	end
	vim.b.virtcolumn_items = items

	local ctx = get_win_context()

	if #items == 0 then
		api.nvim_buf_clear_namespace(curbuf, NS, 0, -1)
		return
	end

	local extend = math.floor(ctx.height * 0.4)
	local offset = math.max(0, ctx.topline - extend)
	local lines = get_buf_lines(curbuf, offset, ctx.botline + extend)

	local virt_char = vim.g.virtcolumn_char or M.config.char
	local virt_priority = vim.g.virtcolumn_priority or M.config.priority

	local tabstop = vim.bo[curbuf].tabstop
	if tabstop < 1 then
		tabstop = 8
	end
	local leftcol = ctx.leftcol
	local line, lnum
	for idx = 1, #lines do
		line = lines[idx]
		lnum = idx - 1 + offset
		api.nvim_buf_clear_namespace(curbuf, NS, lnum, lnum + 1)
		for _, item in ipairs(items) do
			-- `item` is a 1-indexed display column. Only draw the guide when that
			-- display cell holds no real glyph; a byte-index check would miss
			-- tabs and wide (CJK) chars and lay the guide on top of real code.
			if is_display_cell_empty(line, item, tabstop) then
				api.nvim_buf_set_extmark(curbuf, NS, lnum, 0, {
					virt_text = { { virt_char, "VirtColumn" } },
					hl_mode = "combine",
					virt_text_win_col = item - 1 - leftcol,
					priority = virt_priority,
				})
			end
		end
	end
end

-- Debounce scroll/text-change bursts to avoid over-refreshing.
local winscrolled_timer
local textchanged_timer
local function refresh(args)
	---@type string
	local event = args.event or ""
	-- Filetype or file path may have changed -> re-run language detection with
	-- the (possibly new) filetype. Only discard columns that CAME FROM
	-- detection; an explicit colorcolumn/textwidth the user set must survive a
	-- filetype change (explicit always wins).
	if event == "FileType" or event == "BufRead" then
		vim.b.virtcolumn_detected = nil
		if vim.b.virtcolumn_source ~= "explicit" then
			vim.b.virtcolumn_items = nil
		end
	end
	if event == "WinScrolled" then
		if winscrolled_timer and winscrolled_timer:is_active() then
			winscrolled_timer:stop()
			winscrolled_timer:close()
		end
		winscrolled_timer = vim.defer_fn(_refresh, 20)
	elseif event:match("TextChanged") then
		if textchanged_timer and textchanged_timer:is_active() then
			textchanged_timer:stop()
			textchanged_timer:close()
		end
		local lines_count = api.nvim_buf_line_count(0)
		local delay
		if lines_count ~= vim.b.virtcolumn_lines_count then
			vim.b.virtcolumn_lines_count = lines_count
			delay = 10
		else
			delay = 20
		end
		textchanged_timer = vim.defer_fn(_refresh, delay)
	else
		_refresh()
	end
end

local function set_hl()
	-- Use ColorColumn's background as the guide colour; else link to NonText.
	local cc = api.nvim_get_hl(0, { name = "ColorColumn" })
	if cc and cc.bg then
		api.nvim_set_hl(0, "VirtColumn", { fg = cc.bg, default = true })
	else
		vim.cmd([[hi default link VirtColumn NonText]])
	end
end

local _did_setup = false

function M.setup(opts)
	if _did_setup then
		return
	end
	_did_setup = true
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local group = api.nvim_create_augroup("virtcolumn", {})
	api.nvim_create_autocmd({
		"CursorHold",
		"FileType",
		"WinScrolled",
		"WinResized",
		"TextChanged",
		"TextChangedI",
		"WinEnter",
		"BufWinEnter",
		"BufRead",
		"InsertLeave",
		"InsertEnter",
		"FileChangedShellPost",
	}, { group = group, callback = refresh })
	api.nvim_create_autocmd("OptionSet", {
		group = group,
		callback = function(ev)
			if ev.match == "textwidth" then
				local curr_cc = api.nvim_get_option_value("cc", { scope = "local" })
				local last_cc = vim.b.virtcolumn_last_cc or vim.w.virtcolumn_last_cc
				local cc = curr_cc ~= "" and curr_cc or last_cc
				if cc then
					api.nvim_set_option_value("cc", cc, { scope = "local" })
				end
			end
			vim.b.virtcolumn_items = nil
			vim.w.virtcolumn_items = nil
			_refresh()
		end,
		pattern = "colorcolumn,textwidth",
	})
	api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })

	pcall(set_hl)
	pcall(_refresh)
end

return M
