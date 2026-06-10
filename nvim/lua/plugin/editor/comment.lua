return {
	"numToStr/Comment.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		-- Neovim 0.12's vim.treesitter.get_parser() returns nil (instead of
		-- erroring) when no parser is installed for the filetype, e.g. dts.
		-- Comment.nvim's ft.calculate doesn't guard that nil and crashes in
		-- ft.contains, so commenting fails with "[Comment.nvim] nil".
		-- Only for buffers without a parser, fall back to the native
		-- &commentstring; filetypes that have a parser return nil here and keep
		-- the original (unchanged) behavior.
		pre_hook = function()
			local ok, parser = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
			if ok and parser ~= nil then
				return nil
			end
			local cms = vim.bo.commentstring
			if cms == nil or cms == "" then
				return nil
			end
			return cms
		end,
	},
}
