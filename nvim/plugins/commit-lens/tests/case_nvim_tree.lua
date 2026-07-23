-- nvim-tree adapter: a touched file and its ancestor directory get the commit-lens
-- glyph + CommitLensSign highlight in the tree; an untouched sibling does not; and
-- both vanish when the lens is cleared.
--
-- nvim-tree is an external dependency. This case DISCOVERS an installed checkout on
-- the runtimepath / lazy data dir and SKIPS (still a pass) if none is found, so the
-- suite stays runnable on a bare machine. When it does run, it wires the decorator
-- exactly as the README instructs and asserts on the rendered tree buffer's extmarks.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

-- Try to locate an nvim-tree checkout and add it to the rtp. Returns true on success.
local function ensure_nvim_tree()
	if pcall(require, "nvim-tree") then
		return true
	end
	local candidates = {}
	-- lazy.nvim default install root for the standard data dir.
	local data = vim.fn.stdpath("data")
	candidates[#candidates + 1] = data .. "/lazy/nvim-tree.lua"
	-- Also honor an explicit override for CI / non-standard layouts.
	if vim.env.NVIM_TREE_DIR and vim.env.NVIM_TREE_DIR ~= "" then
		table.insert(candidates, 1, vim.env.NVIM_TREE_DIR)
	end
	for _, dir in ipairs(candidates) do
		if vim.fn.isdirectory(dir) == 1 then
			vim.opt.rtp:append(dir)
			if pcall(require, "nvim-tree") then
				return true
			end
		end
	end
	return false
end

H.case("nvim-tree", function()
	if not ensure_nvim_tree() then
		print("SKIP nvim-tree (no checkout found; set NVIM_TREE_DIR to run)")
		return -- H.case prints PASS + quits
	end

	local core = H.setup()
	local repo = H.new_repo()
	-- Touched file lives under a subdir so we can also assert the ancestor dir mark.
	-- c1 owns ONLY src/touched.txt.
	H.write(repo, "src/touched.txt", "hello\nworld\n")
	local c1 = H.commit(repo, "add touched")
	-- other.txt + README land in a LATER, unrelated commit, so c1 never owns them
	-- (and a later commit also keeps touched.txt's lines surviving from c1).
	H.write(repo, "src/other.txt", "unrelated\n")
	H.write(repo, "README", "readme\n")
	H.commit(repo, "add other + readme")

	-- Wire the decorator exactly as the README shows, then open the tree rooted at repo.
	require("nvim-tree").setup({
		renderer = {
			decorators = {
				"Git",
				"Open",
				"Hidden",
				"Modified",
				"Bookmark",
				"Diagnostics",
				"Copied",
				require("commit-lens.tree.nvim-tree").decorator,
				"Cut",
			},
		},
	})
	vim.cmd("edit " .. vim.fn.fnameescape(repo .. "/src/touched.txt"))
	vim.cmd("CommitLens " .. c1)
	-- Wait for the tree file set to be blame-confirmed.
	H.wait_until(function()
		return core.tree_files[repo .. "/src/touched.txt"] == true
	end)
	H.ok(core.tree_files[repo .. "/src/touched.txt"] == true, "touched.txt in tree_files")
	H.ok(core.tree_files[repo .. "/src/other.txt"] ~= true, "other.txt NOT in tree_files")
	H.ok(core.tree_dirs[repo .. "/src"] == true, "ancestor dir src/ marked")

	-- Open the tree and confirm CommitLensSign extmarks land in the tree buffer.
	local tapi = require("nvim-tree.api")
	tapi.tree.open({ path = repo })
	tapi.tree.expand_all()
	H.wait_until(function()
		return vim.bo.filetype == "NvimTree" or vim.fn.bufname():find("NvimTree") ~= nil
	end, 2000)
	vim.wait(300) -- let the decorator render
	-- Find the NvimTree buffer.
	local tree_buf
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[b].filetype == "NvimTree" then
			tree_buf = b
			break
		end
	end
	H.ok(tree_buf ~= nil, "found NvimTree buffer")
	-- Any extmark using CommitLensSign hl means the glyph/name recolour rendered.
	local marks = vim.api.nvim_buf_get_extmarks(tree_buf, -1, 0, -1, { details = true })
	local has_cl = false
	for _, m in ipairs(marks) do
		local d = m[4] or {}
		if d.hl_group == "CommitLensSign" or d.sign_hl_group == "CommitLensSign" then
			has_cl = true
			break
		end
	end
	H.ok(has_cl, "CommitLensSign extmark present in the tree while active")

	-- Clearing the lens removes the tree marks.
	core.clear()
	H.wait_until(function()
		return next(core.tree_files) == nil
	end)
	H.ok(next(core.tree_files) == nil, "tree_files emptied after clear")
end)
