-- blame_args (-w -M): a line the commit introduced that was later merely
-- re-indented in the working tree stays credited to that commit with -w, but
-- drops out with no flags. This is the correctness gap the flag closes.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

H.case("blame_args", function()
	local repo = H.new_repo()
	-- c1 adds foo() with a 2-space-indented body.
	H.write(repo, "f.lua", "function foo()\n  local x = 42\n  return x\nend\n")
	local c1 = H.commit(repo, "add foo")
	-- c2 (unrelated) appends bar() so blame of the current file still credits c1
	-- for the foo body.
	H.write(repo, "f.lua", "function foo()\n  local x = 42\n  return x\nend\n\nfunction bar()\n  return 0\nend\n")
	H.commit(repo, "add bar")
	-- Working-tree edit: re-indent foo's body from 2 to 4 spaces. No content change.
	H.write(repo, "f.lua", "function foo()\n    local x = 42\n    return x\nend\n\nfunction bar()\n  return 0\nend\n")

	-- With -w -M the reindented body lines (2,3) stay attributed to c1.
	local core = H.setup({ blame_args = { "-w", "-M" } })
	local buf = H.edit(repo, "f.lua")
	vim.cmd("CommitLens " .. c1)
	local with = H.await_marks(core, buf)
	H.eq(with, { 1, 2, 3, 4 }, "-w -M keeps reindented body attributed")
	core.clear()
	H.await_marks(core, buf, true)

	-- Without flags, the reindented body lines drop out (blame credits the
	-- reindent commit, which isn't in the chosen set).
	core.setup({ blame_args = {} })
	vim.cmd("CommitLens " .. c1)
	-- Await a *different* result than the cleared state; the marks recompute.
	H.wait_until(function()
		return #H.marked_lines(core, buf) > 0
	end)
	local without = H.marked_lines(core, buf)
	H.ok(#without < 4, "no flags: fewer lines credited (reindented body drops)")
	H.ok(without[1] == 1, "no flags: the unchanged signature line 1 still marked")
end)
