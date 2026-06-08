return {
	"ziontee113/icon-picker.nvim",
	keys = {
		{ "<leader><leader>n", "<cmd>IconPickerNormal<cr>", desc = "IconPicker Normal" },
		{ "<leader><leader>y", "<cmd>IconPickerYank<cr>", desc = "IconPicker Yank" },
		-- NOTE: <C-i> is indistinguishable from <Tab> in a terminal, so binding
		-- it in insert mode hijacked blink.cmp's <Tab> and froze insert mode.
		-- Trigger from normal/visual on the same <leader><leader> prefix as
		-- Normal/Yank; IconPickerInsert still inserts the glyph at the cursor.
		{ "<leader><leader>I", "<cmd>IconPickerInsert<cr>", mode = { "n", "x" }, desc = "IconPicker Insert" },
	},
	opts = { disable_legacy_commands = true },
}
