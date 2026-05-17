-- general configuration
-- ref: <https://www.ruanyifeng.com/blog/2018/09/vimrc.html>

-- set vim leader to <space>
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- disable netrw early so nvim-tree can take over without races
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Disable language providers we don't use (silences :checkhealth warnings
-- and skips a fork/exec at startup for each).
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- open doxygen syntax highlight
vim.g.load_doxygen_syntax = 1

-- window & popup transparency
vim.opt.pumblend = 10
vim.opt.winblend = 0

-- sync buffer automatically
vim.opt.autoread = true

-- line number
vim.opt.relativenumber = true -- show relative line number
vim.opt.number = true -- show line number

-- highlight
vim.opt.cursorline = true -- highlight the line where the cursor points

-- tab
-- ref: <https://www.jianshu.com/p/162c19cc9c11>
vim.opt.tabstop = 8 -- determine one tab length is 8 space
vim.opt.shiftwidth = 8 -- indent length for each level, usually equals to 'tabstop'
vim.opt.softtabstop = 8 -- control tab and backspace
vim.opt.expandtab = false -- use space to replace the tab
vim.opt.autoindent = true -- the new tab level will use the same format as previous ones
vim.opt.smartindent = true

-- render
vim.opt.termguicolors = true -- the nvim terminal will become colorful
vim.opt.conceallevel = 2

-- coding
vim.opt.wrap = false -- don't wrap the codes when too long

-- search
vim.opt.ignorecase = true -- ignore the case while searching
vim.opt.smartcase = true -- if 'ignorecase' is also true, case sensitive when exists only one uppercase character, otherwise not

-- spell check
vim.opt.spelllang = "en_us,cjk"
vim.opt.spell = false

-- split windows
vim.opt.splitright = true -- prefer to split the new windows right
vim.opt.splitbelow = true -- prefer to split the new windows below
vim.opt.title = true

-- appearance
vim.opt.signcolumn = "yes"

-- other
vim.opt.formatoptions = vim.opt.formatoptions
	- "t" -- wrap with text width
	+ "c" -- wrap comments
	- "r" -- insert comment after enter
	- "o" -- insert comment after o/O
	- "q" -- allow formatting of comments with gq
	- "a" -- format paragraphs
	+ "n" -- recognized numbered lists
	- "2" -- use indent of second line for paragraph
	+ "l" -- long lines are not broken
	+ "j" -- remove comment when joining lines

-- vim.o.winbar = " %{%v:lua.vim.fn.expand('%F')%}  %{%v:lua.require'nvim-navic'.get_location()%}"

if vim.fn.executable("clipboard-provider") == 1 then
	vim.g.clipboard = {
		name = "self-clipboard",
		copy = {
			["+"] = "clipboard-provider copy",
			["*"] = "clipboard-provider copy",
		},
		paste = {
			["+"] = "clipboard-provider paste",
			["*"] = "clipboard-provider paste",
		},
	}
	-- Route yank/put through the system clipboard via the provider above.
	-- vim.g.clipboard is set explicitly, so Neovim skips its usual clipboard
	-- probe at startup; setting this synchronously has no startup cost.
	vim.opt.clipboard = "unnamedplus"
end
