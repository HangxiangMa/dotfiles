-- Live-typing helpers for inactive_regions.
-- Loaded only when InactiveRegions.config.live_typing is true.
--
-- Status: experimental / proof-of-concept. Bugs expected.
--
-- The parent module passes its mutable state and a small set of helpers via
-- `attach()`, then calls `setup_autocmds()`. Keeping the surface explicit makes
-- it easy to see what live typing actually depends on from the core module.

local M = {}

---@class InactiveRegionsLiveTypingDeps
---@field config table          -- shared config table (read-only from here)
---@field state  table          -- shared _state table (we mutate live_typing_state)
---@field ns     integer        -- the buffer-extmark namespace from core
---@field log    fun(fmt:string, ...:any)
---@field get_or_create_inactive_highlight fun(capture_name: string): string
---@field get_blended_color   fun(fg: string, bg: string, opacity: number): string
---@field get_background_color fun(): string
---@field get_highlight_color fun(group: string, attr: string): string

---@type InactiveRegionsLiveTypingDeps?
local D

---Bind the parent module's state and helpers.
---@param deps InactiveRegionsLiveTypingDeps
function M.attach(deps)
	D = deps
end

local function check_word_boundary_typed(bufnr, row, col)
	if col == 0 then
		return false
	end

	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line or col > #line then
		return false
	end

	local char = line:sub(col, col)
	local boundary_chars = D.config.boundary_chars

	if not boundary_chars:find(char, 1, true) then
		return false
	end

	local word_start = col - 1
	while word_start >= 1 do
		local prev_char = line:sub(word_start, word_start)
		if boundary_chars:find(prev_char, 1, true) then
			break
		end
		if prev_char:match("%w") then
			return true
		end
		word_start = word_start - 1
	end

	return false
end

---Extract the word that was just completed before the cursor.
---Exposed because the InactiveRegionsDebugWord command also calls it.
---@return string|nil, integer|nil, integer|nil
function M.extract_word_before_cursor(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line or col == 0 then
		return nil
	end

	local boundary_chars = D.config.boundary_chars

	local just_typed_boundary = false
	if col <= #line then
		local char_at_cursor = line:sub(col, col)
		just_typed_boundary = boundary_chars:find(char_at_cursor, 1, true) ~= nil
	end

	local search_start = just_typed_boundary and (col - 1) or col
	local start_col = search_start
	while start_col >= 1 do
		local char = line:sub(start_col, start_col)
		if boundary_chars:find(char, 1, true) then
			start_col = start_col + 1
			break
		end
		start_col = start_col - 1
	end
	start_col = math.max(start_col, 1)

	local end_col = just_typed_boundary and (col - 1) or col
	while end_col <= #line do
		local char = line:sub(end_col + 1, end_col + 1)
		if not char or char == "" or boundary_chars:find(char, 1, true) then
			break
		end
		end_col = end_col + 1
	end

	if start_col > end_col then
		return nil
	end

	local word = line:sub(start_col, end_col)
	return word, start_col - 1, end_col
end

local function update_word_highlight_with_treesitter(bufnr, row, start_col, end_col, word)
	local lstate = D.state.live_typing_state
	local existing_timer = lstate.typing_timers[bufnr]
	if existing_timer then
		vim.fn.timer_stop(existing_timer)
		lstate.typing_timers[bufnr] = nil
		D.log("Cancelled pending immediate character highlighting timer for word boundary")
	end

	local all_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, D.ns, { row, 0 }, { row, -1 }, { details = true })

	local cleared_count = 0
	for _, mark in ipairs(all_extmarks) do
		local mark_id, _, mark_col, mark_details = mark[1], mark[2], mark[3], mark[4]

		local should_clear = false
		if mark_details and mark_details.hl_group then
			if mark_details.hl_group == "InactiveRegions_LiveTyping" then
				should_clear = true
			else
				local mark_start = mark_col
				local mark_end = mark_details.end_col or mark_col + 1
				if not (mark_end <= start_col or mark_start >= end_col + 1) then
					should_clear = true
				end
			end
		end

		if should_clear then
			vim.api.nvim_buf_del_extmark(bufnr, D.ns, mark_id)
			cleared_count = cleared_count + 1
		end
	end

	D.log("Cleared %d overlapping extmarks from line %d, preserving others", cleared_count, row)

	local captures = vim.treesitter.get_captures_at_pos(bufnr, row, start_col)
	local highlight_group = "InactiveRegions_LiveTyping"
	local capture_name = nil

	for _, capture in ipairs(captures) do
		if capture.capture then
			capture_name = capture.capture
			highlight_group = D.get_or_create_inactive_highlight(capture_name)
			break
		end
	end

	if capture_name then
		D.log("Word '%s' identified as @%s, applying highlight %s", word, capture_name, highlight_group)
	else
		local bg_color = D.get_background_color()
		local fg_color = D.get_highlight_color("Normal", "fg")
		local blended_color = D.get_blended_color(fg_color, bg_color, D.config.opacity)

		highlight_group = "InactiveRegions_LiveTyping"
		vim.api.nvim_set_hl(0, highlight_group, {
			fg = blended_color,
			default = false,
		})

		D.log("Word '%s' has no treesitter capture, using default highlight", word)
	end

	D.log("Applying highlight '%s' for word '%s' at (%d,%d-%d)", highlight_group, word, row, start_col, end_col)

	vim.api.nvim_buf_add_highlight(bufnr, D.ns, highlight_group, row, start_col, end_col + 1)

	if lstate.temp_highlights[bufnr] then
		lstate.temp_highlights[bufnr] = {}
	end
end

local function analyze_and_update_completed_word(bufnr, row, col)
	local word, start_col, end_col = M.extract_word_before_cursor(bufnr, row, col)
	if not word or word == "" then
		D.log("No word found at boundary at (%d,%d)", row, col)
		return
	end

	D.log("Word boundary detected: analyzing word '%s' at (%d,%d-%d)", word, row, start_col, end_col)
	update_word_highlight_with_treesitter(bufnr, row, start_col, end_col, word)
end

local function clear_temp_highlights(bufnr)
	local lstate = D.state.live_typing_state
	local highlight_data = lstate.temp_highlights[bufnr]

	if highlight_data then
		for _, hl in ipairs(highlight_data) do
			if hl.id then
				pcall(vim.api.nvim_buf_del_extmark, bufnr, D.ns, hl.id)
			end
		end

		lstate.temp_highlights[bufnr] = {}
		D.log("Cleared %d temp highlights for buffer %d", #highlight_data, bufnr)
	end

	local all_marks = vim.api.nvim_buf_get_extmarks(bufnr, D.ns, 0, -1, { details = true })

	local cleared_count = 0
	for _, mark in ipairs(all_marks) do
		local mark_id, _, _, mark_details = mark[1], mark[2], mark[3], mark[4]
		if mark_details and mark_details.hl_group == "InactiveRegions_LiveTyping" then
			vim.api.nvim_buf_del_extmark(bufnr, D.ns, mark_id)
			cleared_count = cleared_count + 1
		end
	end

	if cleared_count > 0 then
		D.log("Cleared %d additional InactiveRegions_LiveTyping highlights", cleared_count)
	end

	lstate.last_typed_pos[bufnr] = nil
end

local function apply_temp_highlights_to_range(bufnr, start_row, start_col, end_row, end_col)
	local lstate = D.state.live_typing_state
	clear_temp_highlights(bufnr)

	local bg_color = D.get_background_color()
	local fg_color = D.get_highlight_color("Normal", "fg")
	local blended_color = D.get_blended_color(fg_color, bg_color, D.config.opacity)

	local temp_group = "InactiveRegions_LiveTyping"
	vim.api.nvim_set_hl(0, temp_group, { fg = blended_color, default = false })

	local highlight_data = {}
	for line = start_row, end_row do
		local line_start_col = line == start_row and start_col or 0
		local line_end_col = line == end_row and end_col or -1

		local existing_marks = vim.api.nvim_buf_get_extmarks(
			bufnr,
			D.ns,
			{ line, line_start_col },
			{ line, line_end_col == -1 and -1 or line_end_col },
			{ details = false }
		)

		for _, mark in ipairs(existing_marks) do
			vim.api.nvim_buf_del_extmark(bufnr, D.ns, mark[1])
		end

		local hl_id = vim.api.nvim_buf_add_highlight(bufnr, D.ns, temp_group, line, line_start_col, line_end_col)

		table.insert(highlight_data, {
			id = hl_id,
			row = line,
			start_col = line_start_col,
			end_col = line_end_col == -1 and math.huge or line_end_col,
			group = temp_group,
		})

		D.log(
			"Applied temp highlight to line %d, cols %d-%s",
			line,
			line_start_col,
			line_end_col == -1 and "end" or tostring(line_end_col)
		)
	end

	lstate.temp_highlights[bufnr] = highlight_data
end

local function apply_live_typing_highlights(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local lstate = D.state.live_typing_state

	if D.config.word_boundary_update and check_word_boundary_typed(bufnr, row, col) then
		D.log("Skipping live typing highlights - word boundary detected")
		return
	end

	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return
	end

	local boundary_chars = D.config.boundary_chars

	local word_start = col
	while word_start > 0 do
		local char = line:sub(word_start, word_start)
		if boundary_chars:find(char, 1, true) then
			word_start = word_start + 1
			break
		end
		word_start = word_start - 1
	end
	word_start = math.max(word_start, 1)

	local word_end = col
	while word_end <= #line do
		local char = line:sub(word_end + 1, word_end + 1)
		if not char or char == "" or boundary_chars:find(char, 1, true) then
			break
		end
		word_end = word_end + 1
	end

	local start_col = word_start - 1
	local end_col = word_end

	lstate.last_typed_pos[bufnr] = { row = row, col = col }

	if D.config.immediate_char_highlight and start_col < end_col then
		apply_temp_highlights_to_range(bufnr, row, start_col, row, end_col)
		local word = line:sub(word_start, word_end)
		D.log(
			"Applied live typing highlights to entire word '%s' at buffer %d, range (%d,%d-%d)",
			word,
			bufnr,
			row,
			start_col,
			end_col
		)
	end
end

local function handle_live_typing(bufnr)
	local lstate = D.state.live_typing_state

	local existing_timer = lstate.typing_timers[bufnr]
	if existing_timer then
		vim.fn.timer_stop(existing_timer)
		lstate.typing_timers[bufnr] = nil
	end

	if D.config.word_boundary_update then
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1] - 1, cursor[2]

		if check_word_boundary_typed(bufnr, row, col) then
			clear_temp_highlights(bufnr)
			analyze_and_update_completed_word(bufnr, row, col)
			return
		end
	end

	if D.config.immediate_char_highlight then
		local timer = vim.fn.timer_start(D.config.typing_debounce_ms, function()
			lstate.typing_timers[bufnr] = nil
			apply_live_typing_highlights(bufnr)
		end)
		lstate.typing_timers[bufnr] = timer
	end
end

local function is_position_in_region(row, col, region)
	if row < region.start.line or row > region["end"].line then
		return false
	end
	if row == region.start.line and col < region.start.character then
		return false
	end
	if row == region["end"].line and col > region["end"].character then
		return false
	end
	return true
end

local function update_cursor_inactive_status(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	if not filename or filename == "" then
		return
	end

	local regions = D.state.region_cache[filename]
	if not regions then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local in_inactive = false

	for _, region in ipairs(regions) do
		if is_position_in_region(row, col, region) then
			in_inactive = true
			break
		end
	end

	D.state.live_typing_state.cursor_in_inactive[bufnr] = in_inactive
	D.log("Cursor in inactive region for buffer %d: %s", bufnr, tostring(in_inactive))
end

local function is_cursor_in_inactive_region(bufnr)
	return D.state.live_typing_state.cursor_in_inactive[bufnr] or false
end

local function reapply_typed_highlights(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	if not filename or filename == "" then
		return
	end
	if not is_cursor_in_inactive_region(bufnr) then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local captures = vim.treesitter.get_captures_at_pos(bufnr, row, col)
	if #captures > 0 then
		for _, capture in ipairs(captures) do
			if capture.capture then
				local highlight_group = D.get_or_create_inactive_highlight(capture.capture)
				vim.api.nvim_buf_add_highlight(bufnr, D.ns, highlight_group, row, math.max(0, col - 1), col + 1)
			end
		end
		D.log("Reapplied proper highlights for typed content in buffer %d", bufnr)
	end
end

---Set up live-typing autocommands. Caller passes the parent augroup so its
---autocmds tear down with the rest of the module.
---@param augroup integer
function M.setup_autocmds(augroup)
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = augroup,
		callback = function(args)
			update_cursor_inactive_status(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("TextChangedI", {
		group = augroup,
		callback = function(args)
			if is_cursor_in_inactive_region(args.buf) then
				handle_live_typing(args.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("CursorMovedI", {
		group = augroup,
		callback = function(args)
			update_cursor_inactive_status(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = augroup,
		callback = function(args)
			clear_temp_highlights(args.buf)
		end,
	})

	-- Custom "TSReparse" event: after treesitter re-parses, fix up any temporary
	-- highlights with treesitter-aware ones. The dispatcher of this event is
	-- expected to provide the buffer in args.buf.
	vim.api.nvim_create_autocmd("User", {
		group = augroup,
		pattern = "TSReparse",
		callback = function(args)
			local bufnr = args.buf or vim.api.nvim_get_current_buf()
			if is_cursor_in_inactive_region(bufnr) then
				reapply_typed_highlights(bufnr)
			end
		end,
	})
end

return M
