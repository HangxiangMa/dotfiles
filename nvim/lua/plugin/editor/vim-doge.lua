return {
	"kkoomen/vim-doge",
	event = { "BufReadPre", "BufNewFile" },
	build = function()
		vim.fn["doge#install"]()
	end,
	config = function()
        -- vim-doge
        vim.g.doge_enable_mappings = 0
        vim.g.doge_mapping = "gDt"
        vim.keymap.set("n", "gDc", "<Plug>(doge-generate)")

        -- Interactive mode comment todo-jumping
        vim.keymap.set("n", "<TAB>", "<Plug>(doge-comment-jump-forward)")
        vim.keymap.set("n", "<S-TAB>", "<Plug>(doge-comment-jump-backward)")
        vim.keymap.set("i", "<TAB>", "<Plug>(doge-comment-jump-forward)")
        vim.keymap.set("i", "<S-TAB>", "<Plug>(doge-comment-jump-backward)")
        vim.keymap.set("x", "<TAB>", "<Plug>(doge-comment-jump-forward)")
        vim.keymap.set("x", "<S-TAB>", "<Plug>(doge-comment-jump-backward)")
	end,
}
