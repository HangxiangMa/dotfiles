-- Reference list:
-- https://github.com/lettertwo/config/blob/0b56ed8f5b0e8c1186ca29cbf8623ed64976568e/nvim/lua/config/keymaps.lua

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- ---------- Usage Description ----------
-- <C-?> means 'ctrl + ?'
-- <A-?> means 'alt + ?'
-- ---------------------------------------

keymap.set("i", "<C-[>", "<ESC>", opts)
keymap.set("n", "<leader>q", ":q!<CR>", opts)
keymap.set("n", "<leader>Q", ":qa!<CR>", opts)

-- visual line
-- no highlight
keymap.set("n", "<leader>nh", ":nohl<CR>", opts)

-- split windows vertically or horizontally
-- keymap.set("n", "<leader>sv", ":vsp<CR>", opts)
-- keymap.set("n", "<leader>sh", ":sp<CR>", opts)

-- close current window <C-w>c
-- close other window <C-w>o

-- indent code in 'Normal Mode'
keymap.set("v", "<", "<gv", opts)
keymap.set("v", ">", ">gv", opts)

-- move code up or down in 'Normal Mode'
keymap.set("v", "J", ":move '>+1<CR>gv-gv", opts)
keymap.set("v", "K", ":move '<-2<CR>gv-gv", opts)

-- control window left/right size
keymap.set("n", "<C-Left>", ":vertical resize +2<CR>", opts)
keymap.set("n", "<C-Right>", ":vertical resize -2<CR>", opts)

-- control window up/down size
keymap.set("n", "<C-Down>", ":resize +2<CR>", opts)
keymap.set("n", "<C-Up>", ":resize -2<CR>", opts)

-- equivalent scale: <C-w>=

-- close all floating windows
--[[ keymap.set("n", "<esc>", function()
	-- local closed_windows = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= "" then -- is_floating_window?
                vim.api.nvim_win_close(win, false) -- do not force
                -- table.insert(closed_windows, win)
            end
        end
	end
	-- print(string.format("Closed %d windows: %s", #closed_windows, vim.inspect(closed_windows)))
end) ]]

