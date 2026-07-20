-- virtcolumn: draws a thin character guide at the line-length limit instead of
-- a solid ColorColumn block. Vendored locally (nvim/plugins/virtcolumn) from
-- xiyaowong/virtcolumn.nvim (MIT) with two local additions:
--
--   * language recognition — when a buffer has no 'colorcolumn'/'textwidth',
--     the guide column is read from the project's formatter config:
--     .clang-format ColumnLimit (c/cpp/objc/cuda/proto), rustfmt max_width
--     (rust), black/ruff/flake8 line length (python). With no config, it falls
--     back to that tool's own default (clang 80 / rust 100 / black 88), so the
--     guide shows up even outside a configured project. Explicit cc/tw wins.
--   * upstream issue #12 fix — the guide's extmark priority defaults to 1 so it
--     renders *under* LSP inlay hints / diagnostics instead of hiding them.
--
-- Loaded on file open so the guide is present without an explicit cc.
return {
	"virtcolumn",
	dir = vim.fn.stdpath("config") .. "/plugins/virtcolumn",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("virtcolumn").setup()
	end,
}
