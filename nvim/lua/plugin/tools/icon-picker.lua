return {
	"ziontee113/icon-picker.nvim",
	keys = {
		{ "<leader><leader>i", "<cmd>IconPickerNormal<cr>", desc = "IconPicker Normal" },
		{ "<leader><leader>y", "<cmd>IconPickerYank<cr>", desc = "IconPicker Yank" },
		{ "<C-i>", "<cmd>IconPickerInsert<cr>", mode = "i", desc = "IconPicker Insert" },
	},
	opts = { disable_legacy_commands = true },
}
