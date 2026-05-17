local function check_lazygit()
	local crisp = require("core.crisp")
	if vim.fn.executable("lazygit") ~= 1 then
		crisp.warn("Package 'lazygit' not installed. Run 'requirements.sh' to install it.", "lazygit")
	end
end

return {
	{
		"kdheepak/lazygit.nvim",
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		lazy = true,
		build = function()
			check_lazygit()
		end,
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},
}
