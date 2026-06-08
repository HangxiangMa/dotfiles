return {
	"ziontee113/icon-picker.nvim",
	keys = {
		{ "<leader><leader>n", "<cmd>IconPickerNormal<cr>", desc = "IconPicker Normal" },
		{ "<leader><leader>y", "<cmd>IconPickerYank<cr>", desc = "IconPicker Yank" },
		-- NOTE: <C-i> is indistinguishable from <Tab> in a terminal, so binding
		-- it here hijacked blink.cmp's <Tab> and froze insert mode. Keep insert
		-- on the same <leader><leader> prefix as Normal/Yank instead.
		{ "<leader><leader>I", "<cmd>IconPickerInsert<cr>", mode = "i", desc = "IconPicker Insert" },
	},
	opts = { disable_legacy_commands = true },
}
