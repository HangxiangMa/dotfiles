return {
	"MysticalDevil/inlay-hints.nvim",
	event = "LspAttach",
	dependencies = { "neovim/nvim-lspconfig" },
	config = function()
		local inlay_hints = require("inlay-hints")
		inlay_hints.setup({
			commands = { enable = true }, -- Enable InlayHints commands, include `InlayHintsToggle`, `InlayHintsEnable` and `InlayHintsDisable`
			-- autocmd auto-enable is off: the plugin's LspAttach handler enables
			-- hints for the whole buffer with no size cap, and inlay hints re-
			-- request on every scroll/edit. We attach our own LspAttach that
			-- gates by line count so large files skip hints (still toggleable
			-- via :InlayHintsToggle).
			autocmd = { enable = false },
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("inlay_hints_guarded", { clear = true }),
			callback = function(args)
				if vim.api.nvim_buf_line_count(args.buf) > 12000 or vim.bo[args.buf].filetype == "bigfile" then
					return
				end
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				if client then
					inlay_hints.on_attach(client, args.buf)
				end
			end,
		})
	end,
}
