-- Shared helpers for the commit-lens headless tests.
--
-- These tests run under `nvim --headless -u NONE` (no user config), so they add
-- ONLY the plugin's own dir to the runtimepath and drive the public API directly.
-- Each case builds a throwaway git repo in a fresh tmp dir, activates the lens,
-- pumps the event loop until the async blame lands, then asserts on the resulting
-- extmarks. Any assertion failure aborts the nvim process with a non-zero exit so
-- the shell runner (run.sh) can tell pass from fail.

local H = {}

-- Absolute path to the plugin root (…/commit-lens), derived from this file's own
-- location so the tests are runnable from anywhere.
function H.plugin_root()
	local src = debug.getinfo(1, "S").source:sub(2) -- strip leading "@"
	-- src = <root>/tests/helpers.lua → go up two levels.
	return vim.fn.fnamemodify(src, ":p:h:h")
end

-- Put the plugin on the runtimepath and require its core. Call once per case.
---@return table core  -- the commit-lens module
function H.setup(opts)
	vim.opt.rtp:append(H.plugin_root())
	local core = require("commit-lens")
	core.setup(opts or {})
	return core
end

-- Run a shell command list in `dir`, assert it succeeded, return trimmed stdout.
local function git(dir, args)
	local cmd = { "git", "-C", dir }
	vim.list_extend(cmd, args)
	local out = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		error("git " .. table.concat(args, " ") .. " failed:\n" .. out)
	end
	return (out:gsub("%s+$", ""))
end

-- Create a fresh throwaway git repo under a unique tmp dir and return its path.
-- Deterministic identity so commits are reproducible.
function H.new_repo()
	local dir = vim.fn.tempname() -- unique, auto-under $TMPDIR
	vim.fn.mkdir(dir, "p")
	git(dir, { "init", "-q" })
	git(dir, { "config", "user.email", "test@commit-lens" })
	git(dir, { "config", "user.name", "commit-lens tests" })
	git(dir, { "config", "commit.gpgsign", "false" })
	return dir
end

-- Write `contents` (a string) to <repo>/<relpath>, creating parent dirs.
function H.write(repo, relpath, contents)
	local path = repo .. "/" .. relpath
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	local fd = assert(io.open(path, "w"))
	fd:write(contents)
	fd:close()
end

-- Stage everything and commit; return the new full SHA.
function H.commit(repo, msg)
	git(repo, { "add", "-A" })
	git(repo, { "commit", "-q", "-m", msg })
	return git(repo, { "rev-parse", "HEAD" })
end

-- Open a repo file in the current window and return its bufnr.
function H.edit(repo, relpath)
	vim.cmd("edit! " .. vim.fn.fnameescape(repo .. "/" .. relpath))
	return vim.api.nvim_get_current_buf()
end

-- Pump the event loop until `pred()` is true or the timeout elapses. Returns
-- whether the predicate held. Used to await the async blame/render.
function H.wait_until(pred, timeout_ms)
	timeout_ms = timeout_ms or 5000
	local step = 25
	for _ = 1, math.ceil(timeout_ms / step) do
		if pred() then
			return true
		end
		vim.wait(step)
	end
	return pred()
end

-- Sorted list of 1-based line numbers currently carrying a commit-lens extmark.
function H.marked_lines(core, bufnr)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, core.ns, 0, -1, {})
	local seen, lines = {}, {}
	for _, m in ipairs(marks) do
		local lnum = m[2] + 1
		if not seen[lnum] then
			seen[lnum] = true
			lines[#lines + 1] = lnum
		end
	end
	table.sort(lines)
	return lines
end

-- Await and return the marked lines after they first become non-empty (or the
-- timeout). Pass want_empty=true to instead await them going empty.
function H.await_marks(core, bufnr, want_empty, timeout_ms)
	H.wait_until(function()
		local n = #H.marked_lines(core, bufnr)
		return want_empty and n == 0 or n > 0
	end, timeout_ms)
	return H.marked_lines(core, bufnr)
end

-- Assert two arrays are equal; on mismatch, abort with a readable message.
function H.eq(got, want, label)
	local function fmt(t)
		return type(t) == "table" and ("{" .. table.concat(vim.tbl_map(tostring, t), ",") .. "}") or tostring(t)
	end
	local same = type(got) == type(want)
	if same and type(got) == "table" then
		same = #got == #want
		for i = 1, #got do
			if got[i] ~= want[i] then
				same = false
			end
		end
	elseif same then
		same = got == want
	end
	if not same then
		error(string.format("[%s] expected %s, got %s", label or "eq", fmt(want), fmt(got)), 2)
	end
end

function H.ok(cond, label)
	if not cond then
		error("[" .. (label or "ok") .. "] assertion failed", 2)
	end
end

-- Wrap a case body: prints "PASS <name>" on success, or "FAIL <name>: <err>" and
-- exits non-zero on the first error, so the shell runner sees the process code.
function H.case(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		-- Leading newline so this line always starts clean, even after commands
		-- that write progress without a trailing newline (e.g. :checkhealth).
		print("\nPASS " .. name)
		vim.cmd("qa!")
	else
		io.stderr:write("\nFAIL " .. name .. ": " .. tostring(err) .. "\n")
		vim.cmd("cq!") -- quit with non-zero exit status
	end
end

return H
