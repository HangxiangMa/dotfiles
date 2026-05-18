return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeoutlen = 300
		vim.o.timeout = true
	end,
	dependencies = {
		"echasnovski/mini.icons",
		{ "nvim-tree/nvim-web-devicons", lazy = false },
	},
	config = function()
		local which_key = require("which-key")
		local setup = {
			preset = "modern",
			plugins = {
				marks = true, -- shows a list of your marks on ' and `
				registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
				spelling = {
					enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
					suggestions = 20, -- how many suggestions should be shown in the list?
				},
				-- the presets plugin, adds help for a bunch of default keybindings in Neovim
				-- No actual key bindings are created
				presets = {
					operators = true, -- adds help for operators like d, y, ... and registers them for motion / text object completion
					motions = true, -- adds help for motions
					text_objects = true, -- help for text objects triggered after entering an operator
					windows = true, -- default bindings on <c-w>
					nav = true, -- misc bindings to work with windows
					z = true, -- bindings for folds, spelling and others prefixed with z
					g = true, -- bindings for prefixed with g
				},
			},
			layout = {
				height = { min = 4, max = 25 }, -- min and max height of the columns
				width = { min = 20, max = 50 }, -- min and max width of the columns
				spacing = 3, -- spacing between columns
				align = "left", -- align columns left, center or right
			},
			show_help = true, -- show help message on the command line when the popup is visible
			show_keys = true, -- show the currently pressed key and its label as a message in the command line
			triggers = {
				{ "<auto>", mode = "nixsotc" },
				{ "a", mode = { "n", "v" } },
			},
		}

		which_key.setup(setup)
		which_key.add({
			-- NORMAL mode
			mode = { "n", "v" },
			prefix = "",
			buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
			silent = true, -- use `silent` when creating keymaps
			noremap = true, -- use `noremap` when creating keymaps
			nowait = true, -- use `nowait` when creating keymaps
			expr = false, -- use `expr` when creating keymaps

			-- common
			{ "<leader><leader>", group = "Common" },
			{ "<leader><leader>i", desc = "IconPicker Normal" },
			{ "<leader><leader>y", desc = "IconPicker Yank" },
			{ "<leader><leader>v", desc = "Toggle Visual Whitespace" },
			{ "<leader><leader>s", desc = "Trim Trailing Whitespace" },
			{ "<leader><leader>l", desc = "Trim Trailing Empty Lines" },

			-- Treesitter textobjects: select (operator-pending + visual)
			{ "af", desc = "Function (outer)", mode = { "o", "x" } },
			{ "if", desc = "Function (inner)", mode = { "o", "x" } },
			{ "ac", desc = "Class (outer)", mode = { "o", "x" } },
			{ "ic", desc = "Class (inner)", mode = { "o", "x" } },
			{ "aa", desc = "Argument (outer)", mode = { "o", "x" } },
			{ "ia", desc = "Argument (inner)", mode = { "o", "x" } },
			{ "a/", desc = "Comment (outer)", mode = { "o", "x" } },
			{ "i/", desc = "Comment (inner)", mode = { "o", "x" } },
			-- Treesitter textobjects: move
			{ "]f", desc = "Next function start" },
			{ "[f", desc = "Prev function start" },
			{ "]F", desc = "Next function end" },
			{ "[F", desc = "Prev function end" },
			{ "]c", desc = "Next class start" },
			{ "[c", desc = "Prev class start" },
			{ "]C", desc = "Next class end" },
			{ "[C", desc = "Prev class end" },
			{ "]a", desc = "Next argument" },
			{ "[a", desc = "Prev argument" },

			-- git-conflict: act on conflict markers in any buffer
			{ "co", desc = "Conflict: ours" },
			{ "ct", desc = "Conflict: theirs" },
			{ "cb", desc = "Conflict: both" },
			{ "c0", desc = "Conflict: none" },
			{ "]x", desc = "Conflict: next" },
			{ "[x", desc = "Conflict: prev" },

			-- Yanky put / cycle
			{ "y", desc = "Yank", mode = { "n", "x" } },
			{ "p", desc = "Put after", mode = { "n", "x" } },
			{ "P", desc = "Put before", mode = { "n", "x" } },
			{ "gp", desc = "Put after (cursor)", mode = { "n", "x" } },
			{ "gP", desc = "Put before (cursor)", mode = { "n", "x" } },
			{ "<C-n>", desc = "Yank ring forward" },
			{ "<C-p>", desc = "Yank ring backward" },
			{ "]p", desc = "Put indented after (linewise)" },
			{ "[p", desc = "Put indented before (linewise)" },

			-- vim basic
			{ "<leader>nh", desc = "No Highlights", hidden = true },
			{ "<leader>q", desc = "Quit", hidden = true },
			{ "<leader>Q", desc = "Quit All", hidden = true },
			{ "<leader>b", desc = "Spider b", hidden = true },
			{ "<leader>e", desc = "Spider e", hidden = true },
			{ "<leader>w", desc = "Spider w", hidden = true },
			{ "<leader>W", group = "Window" },
			{ "<leader>Wh", "<cmd>:sp<CR>", desc = "Split Horizontal" },
			{ "<leader>Wv", "<cmd>:vsp<CR>", desc = "Split Vertical" },
			{ "g", group = "General" },
			{ "gd", "<cmd>LspUI definition<cr>", desc = "Goto Definition" },
			{ "gD", "<cmd>LspUI declaration<cr>", desc = "Goto Declaration" },
			{ "gt", "<cmd>LspUI type_definition<cr>", desc = "Goto Type Declaration" },
			{ "gO", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "Document Symbols" },
			{ "gh", "<cmd>LspUI hover<cr>", desc = "Show Hint" },
			{ "gH", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "Show Signature" },
			{ "gi", "<cmd>LspUI implementation<cr>", desc = "Show Implementation" },
			{ "gF", "<cmd>LspUI reference<cr>", desc = "Show References" },
			{ "ga", "<cmd>LspUI code_action<cr>", desc = "LSP Code Action" },
			-- gr is left to Neovim 0.11's default LSP family (grn/gra/grr/gri/grt).
			-- LspUI rename remains available via <leader>kr-style keys.
			{ "gl", "<cmd>LspUI call_hierarchy incoming_calls<cr>", desc = "Incoming Calls" },
			{ "gL", "<cmd>LspUI call_hierarchy outgoing_calls<cr>", desc = "Outgoing Calls" },
			{ "gs", "<cmd>LspUI history<cr>", desc = "Jump History Viewer" },

			-- original
			-- { "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", desc = "Goto Definition" },
			-- { "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", desc = "Goto Declaration" },
			-- { "gt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", desc = "Goto Type Declaration" },
			-- { "gO", "<cmd>lua vim.lsp.buf.document_symbol()<cr>", desc = "Goto Document Symbol" },
			-- { "gh", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "Show Hint" },
			-- { "gH", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "Show Signature" },
			-- { "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", desc = "Show Implementation" },
			-- { "gF", "<cmd>lua vim.lsp.buf.references()<cr>", desc = "Show References" },
			-- { "ga", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "LSP Code Action" },
			-- { "gr", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "Rename" },
			{ "gR", desc = "IncRename" },
			{ "g]", desc = "Goto Tag" },
			{ "gf", desc = "Goto File" },
			{ "g*", desc = "Search Symbol(↑)" },
			{ "g#", desc = "Search Symbol(↓)" },

			-- yazi
			{ "<leader>-", desc = "Yazi" },

			-- Buffer/Tab — uppercase B prefix so it doesn't shadow
			-- nvim-spider's lowercase <leader>b motion.
			{ "<leader>B", group = "Buffer" },
			{ "<leader>B1", "<cmd>BufferLineGoToBuffer 1<CR>", desc = "Goto Buffer 1" },
			{ "<leader>B2", "<cmd>BufferLineGoToBuffer 2<CR>", desc = "Goto Buffer 2" },
			{ "<leader>B3", "<cmd>BufferLineGoToBuffer 3<CR>", desc = "Goto Buffer 3" },
			{ "<leader>B4", "<cmd>BufferLineGoToBuffer 4<CR>", desc = "Goto Buffer 4" },
			{ "<leader>B5", "<cmd>BufferLineGoToBuffer 5<CR>", desc = "Goto Buffer 5" },
			{ "<leader>Bn", desc = "Next Buffer" },
			{ "<leader>Bp", desc = "Previous Buffer" },
			{ "<leader>BP", desc = "Pick Buffer" },
			{ "<leader>Bd", desc = "Close Buffer" },
			{ "<leader>Bc", group = "Close" },
			{ "<leader>Bcp", desc = "Pick and Close" },
			{ "<leader>Bco", desc = "Close Others" },
			{ "<leader>Bcl", desc = "Close Left" },
			{ "<leader>Bcr", desc = "Close Right" },
			{ "<leader>Bm", "<cmd>ArenaToggle<cr>", desc = "Toggle Buffer Menu" },

			-- File
			{ "<leader>f", group = "File" },
			{ "<leader>fB", "<cmd>FzfLua buffers<cr>", desc = "Buffers(All)" },
			{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files(Root)" },
			{
				"<leader>fF",
				"<cmd>lua require('fzf-lua').files({ cwd = vim.fn.expand('%:p:h') })<cr>",
				desc = "Find Files(Buffer Dir)",
			},
			{ "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Open Recent Files" },
			{ "<leader>fo", desc = "Smart Open (frecency)" },
			{ "<leader>fO", desc = "Smart Open (CWD)" },
			{ "<leader>fm", desc = "Format File" },
			{ "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help Tags" },
			{ "<leader>fH", "<cmd>FzfLua highlights<cr>", desc = "Highlights" },
			{ "<leader>fg", "<cmd>FzfLua grep_curbuf<cr>", desc = "Grep in current buffer" },
			{ "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Search word(CWD)" },
			-- File -> Search
			{ "<leader>fs", group = "Search" },
			{ "<leader>fsa", "<cmd>FzfLua autocmds<cr>", desc = "Auto Commands" },
			{ "<leader>fsb", "<cmd>FzfLua lgrep_curbuf<cr>", desc = "Buffer(Live Grep)" },
			{ "<leader>fsc", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
			{ "<leader>fsC", "<cmd>FzfLua commands<cr>", desc = "Commands" },
			{ "<leader>fsd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnostics" },
			{ "<leader>fsg", "<cmd>FzfLua live_grep<cr>", desc = "Grep(CWD)" },
			{ "<leader>fsG", "<cmd>FzfLua live_grep_resume<cr>", desc = "Grep(Resume)" },
			{ "<leader>fsj", "<cmd>FzfLua jumps<cr>", desc = "Jumplist" },
			{ "<leader>fsk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
			{ "<leader>fsm", "<cmd>FzfLua marks<cr>", desc = "Jump to Marks" },
			{ "<leader>fsM", "<cmd>FzfLua manpages<cr>", desc = "Man Pages" },
			{ "<leader>fsq", "<cmd>FzfLua quickfix<cr>", desc = "QuickFix" },
			{ "<leader>fsi", "<cmd>FzfLua builtin<cr>", desc = "FzfLua Builtins" },
			{ "<leader>fst", "<cmd>TodoFzfLua<cr>", desc = "Todo Comments" },
			{ "<leader>fsT", "<cmd>FzfLua tags<cr>", desc = "Tags" },
			{ "<leader>fss", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
			{ "<leader>fsS", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", desc = "Workspace Symbols" },
			{ "<leader>fsr", "<cmd>FzfLua resume<cr>", desc = "Resume Last Picker" },
			-- File -> Wrapping (W to free up R for grug-far style "Replace")
			{ "<leader>fW", group = "Wrapping" },
			{ "<leader>fWs", "<cmd>lua require('wrapping').soft_wrap_mode()<cr>", desc = "Soft Wrap Mode" },
			{ "<leader>fWh", "<cmd>lua require('wrapping').hard_wrap_mode()<cr>", desc = "Hard Wrap Mode" },
			{ "<leader>fWt", "<cmd>lua require('wrapping').toggle_wrap_mode()<cr>", desc = "Toggle Wrap Mode" },
			-- File -> linter
			{ "<leader>fL", "<cmd>lua require('lint').try_lint()<cr>", desc = "Trigger linting" },

			-- Terminal — buffer/tab keys moved to <leader>B*
			{ "<leader>t", group = "Terminal" },
			{ "<leader>tf", desc = "Terminal Float" },
			{ "<leader>th", desc = "Terminal Horizontal" },
			{ "<leader>tv", desc = "Terminal Vertical" },
			{ "<leader>tg", desc = "Lazy Git" },
			{ "<leader>tn", desc = "ncdu" },
			{ "<leader>tt", desc = "htop" },

			-- Git
			{ "<leader>g", group = "Git" },
			{ "<leader>gf", "<cmd>DiffviewFileHistory<CR>", desc = "File History" },
			{ "<leader>gD", "<cmd>DiffviewOpen<CR>", desc = "Diff Project" },
			{ "<leader>gn", "<cmd>lua require 'gitsigns'.next_hunk()<cr>", desc = "Next Hunk" },
			{ "<leader>gp", "<cmd>lua require 'gitsigns'.prev_hunk()<cr>", desc = "Prev Hunk" },
			{ "<leader>gl", "<cmd>lua require 'gitsigns'.blame_line()<cr>", desc = "Blame" },
			{ "<leader>gr", "<cmd>lua require 'gitsigns'.reset_hunk()<cr>", desc = "Reset Hunk" },
			{ "<leader>gR", "<cmd>lua require 'gitsigns'.reset_buffer()<cr>", desc = "Reset Buffer" },
			{ "<leader>gs", "<cmd>lua require 'gitsigns'.stage_hunk()<cr>", desc = "Stage Hunk" },
			{ "<leader>gS", "<cmd>lua require 'gitsigns'.stage_buffer()<cr>", desc = "Stage Buffer" },
			{ "<leader>gu", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", desc = "Undo Stage Hunk" },
			{ "<leader>go", "<cmd>FzfLua git_status<cr>", desc = "Open changed file" },
			{ "<leader>gb", "<cmd>FzfLua git_branches<cr>", desc = "Checkout branch" },
			{ "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Checkout commit" },
			{ "<leader>gd", "<cmd>Gitsigns diffthis HEAD<cr>", desc = "Diffthis" },

			-- diagnostics
			{ "<leader>a", group = "Diagnostics" },
			{
				"<leader>ao",
				"<cmd>lua vim.diagnostic.open_float(nil, {focus=false, scope='cursor', border='rounded'})<cr>",
				desc = "Show Diagnostics",
			},
			{
				"<leader>ap",
				"<cmd>lua vim.diagnostic.goto_prev({float={source=true, border='rounded'}})<cr>",
				desc = "Previous Diagnostics",
			},
			{
				"<leader>an",
				"<cmd>lua vim.diagnostic.goto_next({float={source=true, border='rounded'}})<cr>",
				desc = "Next Diagnostics",
			},
			{
				"<leader>al",
				"<cmd>lua vim.diagnostic.setloclist()<cr>",
				desc = "Diagnostics Location",
			},

			{ "<leader>ac", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics(Buffer)" },
			{ "<leader>ar", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnostics(Workspace)" },

			-- Dap (nvim-dap is currently disabled; keys are registered by the plugin
			-- itself via its `keys` spec when re-enabled. No declarations here.)

			-- Neotest is currently disabled; keys are registered by the plugin's own
			-- spec when re-enabled. No declarations here.

			{ "<leader>M", group = "Makers" },
			{ "<leader>Mg", group = "Groups" },

			-- Replace (grug-far)
			{ "<leader>r", group = "Replace" },
			{ "<leader>rr", desc = "Find/Replace (Project)" },
			{ "<leader>rw", desc = "Find/Replace (cword)" },
			{ "<leader>rb", desc = "Find/Replace (Buffer)" },
			-- visual <leader>r is a real keymap registered by grug-far.lua;
			-- no group declaration needed here.

			-- Yank ring (yanky.nvim)
			{ "<leader>y", group = "Yank" },
			{ "<leader>yp", desc = "Yank History" },

			-- Code: a per-language sub-tree. Hosts treesitter swap, Rust
			-- (rustaceanvim) and Crates so all language-server-driven keys
			-- live under one prefix.
			{ "<leader>c", group = "Code" },
			{ "<leader>cn", group = "Swap-Next" },
			{ "<leader>cna", desc = "Swap parameter forward" },
			{ "<leader>cp", group = "Swap-Prev" },
			{ "<leader>cpa", desc = "Swap parameter backward" },

			-- CscopeMaps registers <leader>m* itself with which-key (group "cscope").
			-- Don't redeclare here; doing so triggers a duplicate-mapping warning.

			-- LSP
			{ "<leader>k", group = "LSP" },
			{ "<leader>kt", desc = "Toggle Signature" },
			{ "<leader>kr", "<cmd>FzfLua lsp_references<cr>", desc = "References" },
			{ "<leader>ki", "<cmd>FzfLua lsp_incoming_calls<cr>", desc = "Incoming Calls" },
			{ "<leader>ko", "<cmd>FzfLua lsp_outgoing_calls<cr>", desc = "Outgoing Calls" },
			{ "<leader>kd", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols(Buffer)" },
			{ "<leader>kw", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
			{ "<leader>kW", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", desc = "Workspace Symbols(Live)" },
			{ "<leader>kI", "<cmd>FzfLua lsp_implementations<cr>", desc = "Implementation" },
			{ "<leader>kD", "<cmd>FzfLua lsp_definitions<cr>", desc = "Definitions" },
			{ "<leader>kT", "<cmd>FzfLua lsp_typedefs<cr>", desc = "Type Definitions" },

			-- Code -> Rust (rustaceanvim)
			{ "<leader>cR", group = "Rust" },
			{ "<leader>cRD", "<cmd>RustLsp debuggables<cr>", desc = "Rust Debuggables" },
			{ "<leader>cRR", "<cmd>RustLsp runnables<cr>", desc = "Rust Runnables" },
			{ "<leader>cRT", "<cmd>RustLsp testables<cr>", desc = "Rust Testables" },
			{ "<leader>cRe", "<cmd>RustLsp expandMacro<cr>", desc = "Expand Macro" },
			{ "<leader>cRb", "<cmd>RustLsp rebuildProcMacros<cr>", desc = "Rebuild ProcMacros" },
			{ "<leader>cRu", "<cmd>RustLsp moveItem up<cr>", desc = "Move item up" },
			{ "<leader>cRd", "<cmd>RustLsp moveItem down<cr>", desc = "Move item down" },
			{ "<leader>cRa", "<cmd>RustLsp codeAction<cr>", desc = "Code Action" },
			{ "<leader>cRh", "<cmd>RustLsp hover actions<cr>", desc = "Hover Actions" },
			{ "<leader>cRn", "<cmd>RustLsp hover range<cr>", desc = "Hover Range" },
			{ "<leader>cRE", "<cmd>RustLsp explainError<cr>", desc = "Explain Error" },
			{ "<leader>cRr", "<cmd>RustLsp renderDiagnostic<cr>", desc = "Render Diagnostic" },
			{ "<leader>cRo", "<cmd>RustLsp openCargo<cr>", desc = "Open cargo" },
			{ "<leader>cRO", "<cmd>RustLsp openDocs<cr>", desc = "Open docs.rs documentation" },
			{ "<leader>cRp", "<cmd>RustLsp parentModule<cr>", desc = "Rust parent module" },
			{ "<leader>cRj", "<cmd>RustLsp joinLines<cr>", desc = "Join lines" },
			{ "<leader>cRS", "<cmd>RustLsp ssr<cr>", desc = "Structural search Replace" },
			{ "<leader>cRg", "<cmd>RustLsp crateGraph<cr>", desc = "View crate graph" },
			{ "<leader>cRt", "<cmd>RustLsp syntaxTree<cr>", desc = "Rust syntax tree" },
			{ "<leader>cRv", "<cmd>RustLsp view hir<cr>", desc = "View rust HIR" },
			{ "<leader>cRV", "<cmd>RustLsp vim mir<cr>", desc = "View rust MIR" },
			{ "<leader>cRs", group = "WorkspaceSymbol" },
			{ "<leader>cRst", "<cmd>RustLsp workspaceSymbol onlyTypes<cr>", desc = "Only type symbols" },
			{ "<leader>cRsa", "<cmd>RustLsp workspaceSymbol allSymbols<cr>", desc = "Show all symbols" },
			{ "<leader>cRf", group = "FlyCheck" },
			{ "<leader>cRfr", "<cmd>RustLsp flyCheck run<cr>", desc = "Run check" },
			{ "<leader>cRfc", "<cmd>RustLsp flyCheck clear<cr>", desc = "Clear check" },
			{ "<leader>cRfn", "<cmd>RustLsp flyCheck cancel<cr>", desc = "Cancel check" },

			-- Code -> Crates (Saecki/crates.nvim)
			{ "<leader>cC", group = "Crates" },
			{ "<leader>cCt", "<cmd>lua require('crates').toggle()<cr>", desc = "Toggle" },
			{ "<leader>cCr", "<cmd>lua require('crates').reload()<cr>", desc = "Reload" },
			{ "<leader>cCv", "<cmd>lua require('crates').show_versions_popup()<cr>", desc = "Show versions" },
			{ "<leader>cCf", "<cmd>lua require('crates').show_features_popup()<cr>", desc = "Show features" },
			{ "<leader>cCd", "<cmd>lua require('crates').show_dependencies_popup()<cr>", desc = "Show dependencies" },
			{ "<leader>cCa", "<cmd>lua require('crates').update_all_crates()<cr>", desc = "Update all crates" },
			{ "<leader>cCA", "<cmd>lua require('crates').upgrade_all_crates()<cr>", desc = "Upgrade all crates" },
			{
				"<leader>cCx",
				"<cmd>lua require('crates').expand_plain_crate_to_inline_table()<cr>",
				desc = "Expand plain crate to inline table",
			},
			{
				"<leader>cCX",
				"<cmd>lua require('crates').extract_crate_into_table()<cr>",
				desc = "Extract crate into table",
			},
			{ "<leader>cCH", "<cmd>lua require('crates').open_homepage()<cr>", desc = "Open homepage" },
			{ "<leader>cCR", "<cmd>lua require('crates').open_repository()<cr>", desc = "Open repository" },
			{ "<leader>cCD", "<cmd>lua require('crates').open_documentation()<cr>", desc = "Open documentation" },
			{ "<leader>cCC", "<cmd>lua require('crates').open_crates_io()<cr>", desc = "Open crates io" },
			{ "<leader>cCu", "<cmd>lua require('crates').update_crate()<cr>", desc = "Update crate" },
			{ "<leader>cCU", "<cmd>lua require('crates').upgrade_crate()<cr>", desc = "Upgrade crate" },
		})
	end,
}
