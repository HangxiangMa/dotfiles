-- Core marking behavior: the right lines light up, unrelated edits short-circuit,
-- get_blocks folds contiguous runs, and clear() removes everything.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

H.case("core", function()
	local core = H.setup()
	local repo = H.new_repo()

	-- c1 owns lines 1..3. c2 changes line 2 and appends line 4.
	H.write(repo, "f.txt", "line one\nline two\nline three\n")
	H.commit(repo, "first")
	H.write(repo, "f.txt", "line one\nline two CHANGED\nline three\nline four\n")
	local c2 = H.commit(repo, "second")

	local buf = H.edit(repo, "f.txt")
	vim.cmd("CommitLens " .. c2)
	local marks = H.await_marks(core, buf)
	-- Only the lines c2 still owns: 2 (changed) and 4 (added).
	H.eq(marks, { 2, 4 }, "c2 marks the changed + added line")

	-- get_blocks folds each into its own singleton block (non-contiguous).
	local blocks = core.get_blocks(buf)
	H.eq(#blocks, 2, "two blocks")
	H.eq({ blocks[1].first, blocks[1].last }, { 2, 2 }, "block 1")
	H.eq({ blocks[2].first, blocks[2].last }, { 4, 4 }, "block 2")

	-- Editing an unrelated region (append a brand-new line) must NOT gain a mark
	-- (it belongs to the working tree, not c2). Await the debounced re-blame.
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "totally new line" })
	vim.wait(1200) -- past edit_debounce (400ms) + blame
	H.eq(H.marked_lines(core, buf), { 2, 4 }, "new line is not attributed to c2")

	-- clear() removes all marks.
	core.clear()
	local empty = H.await_marks(core, buf, true)
	H.eq(empty, {}, "clear removes marks")
	H.ok(core.enabled == false, "disabled after clear")
end)
