-- Async activate + the two race regressions surfaced during design:
--   1. clear() issued while rev-resolution is in flight must NOT re-enable the lens.
--   2. two rapid activates: the last one wins deterministically.
-- Plus the toggle round-trip (off → re-use last set → on) without a picker.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

H.case("async", function()
	local core = H.setup()
	local repo = H.new_repo()
	H.write(repo, "f.txt", "a\nb\nc\n")
	local c1 = H.commit(repo, "first")
	H.write(repo, "f.txt", "a\nb changed\nc\nd\n")
	local c2 = H.commit(repo, "second")
	local buf = H.edit(repo, "f.txt")

	-- REGRESSION 1: activate then immediately clear (resolution still async).
	vim.cmd("CommitLens " .. c2)
	core.clear()
	vim.wait(1500) -- let any in-flight resolution finish and (wrongly) try to commit
	H.ok(core.enabled == false, "R1: lens stays OFF after clear-during-resolution")
	H.eq(H.marked_lines(core, buf), {}, "R1: no marks after clear-during-resolution")

	-- REGRESSION 2: two rapid activates, last wins.
	vim.cmd("CommitLens " .. c1)
	vim.cmd("CommitLens " .. c2)
	H.await_marks(core, buf)
	H.ok(core.enabled, "R2: enabled")
	H.eq(core.last_names, { c2 }, "R2: last activate (c2) wins")
	-- c2's surviving lines are 2 (changed) and 4 (added), NOT c1's whole 1..3.
	H.eq(H.marked_lines(core, buf), { 2, 4 }, "R2: marks are c2's, not c1's")

	-- TOGGLE: off, then back on re-using the last set (no picker), same marks.
	core.toggle()
	H.await_marks(core, buf, true)
	H.ok(core.enabled == false, "toggle off disables")
	core.toggle()
	H.await_marks(core, buf)
	H.ok(core.enabled, "toggle on re-enables from remembered set")
	H.eq(H.marked_lines(core, buf), { 2, 4 }, "toggle on restores the same marks")
end)
