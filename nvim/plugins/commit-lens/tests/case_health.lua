-- :checkhealth commit-lens runs without error and emits the expected sections.
-- Captures the health buffer and asserts the section headers are present and that
-- the core git check reports OK (git is a test prerequisite).
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")

H.case("health", function()
	H.setup()
	vim.cmd("checkhealth commit-lens")
	-- The health report opens in the current buffer.
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(lines, "\n")

	local function has(needle)
		H.ok(text:find(needle, 1, true) ~= nil, "health output contains: " .. needle)
	end
	has("commit-lens: core")
	has("commit-lens: config")
	has("commit-lens: picker (fzf-lua)")
	has("commit-lens: file-tree integrations")
	has("commit-lens: neominimap")
	has("blame_args = { -w, -M }")
	has("git found")
end)
