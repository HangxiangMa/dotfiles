-- In-flight dedup: two renders for the same (buffer, version, tick) — the
-- BufReadPost+BufWinEnter double-fire — must launch only ONE buffer blame, not two.
-- We instrument vim.system to count the buffer-blame subprocesses (those carry
-- `--contents`), fire two renders back-to-back before the first completes, and
-- assert exactly one launched.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

H.case("dedup", function()
	local core = H.setup()
	local repo = H.new_repo()
	H.write(repo, "f.txt", "a\nb\nc\n")
	H.commit(repo, "first")
	H.write(repo, "f.txt", "a\nb changed\nc\n")
	local c2 = H.commit(repo, "second")
	local buf = H.edit(repo, "f.txt")

	-- Activate first and let it settle so buf_cache is populated for this tick.
	vim.cmd("CommitLens " .. c2)
	H.await_marks(core, buf)

	-- Now count buffer blames (--contents) launched by a burst of renders at the
	-- SAME tick. Wrap vim.system for the duration of the burst only.
	local blames = 0
	local real = vim.system
	vim.system = function(cmd, ...)
		if type(cmd) == "table" then
			local has_blame, has_contents = false, false
			for _, a in ipairs(cmd) do
				if a == "blame" then
					has_blame = true
				end
				if a == "--contents" then
					has_contents = true
				end
			end
			if has_blame and has_contents then
				blames = blames + 1
			end
		end
		return real(cmd, ...)
	end

	-- Force a cache miss (bump nothing, but the cache is for the settled tick, so
	-- clear it by editing then restoring is overkill). Instead re-render after a
	-- no-op edit that advances the tick once, then fire the double render for THAT
	-- tick before the blame can complete.
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "prepended" }) -- tick advances
	core.render(buf) -- claim + launch for the new tick
	core.render(buf) -- same (version, tick) → must dedup, NOT launch a 2nd blame

	-- Give the single blame a moment to run, then restore vim.system.
	vim.wait(800)
	vim.system = real

	H.eq({ blames }, { 1 }, "double render at one tick launches exactly one blame")
end)
