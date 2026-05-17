local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

vim.loader.enable() -- speed up Lua module loading; must run before requiring user modules
require("core.options")
vim.api.nvim_command("syntax on")
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("lazy").setup("plugin", {
	ui = {
		border = "rounded",
	},
	checker = { enabled = false }, -- avoid blocking startup with remote update checks
	performance = {
		rtp = {
			-- disable some rtp plugins
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
