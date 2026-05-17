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
			{ "<leader><leader>i", desc = "IconPicker Normal"},
			{ "<leader><leader>y", desc = "IconPicker Yank"},
			{ "<leader><leader>v", desc = "Toggle Visual Whitespace"},
			{ "<leader><leader>s", desc = "Trim Trailing Whitespace"},
			{ "<leader><leader>l", desc = "Trim Trailing Empty Lines"},


			-- vim basic
			{ "<leader>nh", desc = "No Highlights", hidden = true },
			{ "<leader>q", desc = "Quit", hidden = true },
			{ "<leader>Q", desc = "Quit All", hidden = true },
			{ "<leader>b", desc = "Spider b", hidden = true },
			{ "<leader>e", desc = "Spider e", hidden = true },
			{ "<leader>w", desc = "Spider w", hidden = true },
			{ "<leader>W", group = "Window" },
			{ "<leader>Wh", desc = "<cmd>:sp<CR>", "Spilt Horizontal" },
			{ "<leader>Wv", desc = "<cmd>:vsp<CR>", "Spilt Vertical" },
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

			-- Doxygen
			{ "<leader>D", group = "Doge" },
			{ "<leader>Dt", desc = "Trigger Doge" },
			{ "<leader>Dc", desc = "Generate Doxygen Comment" },


			-- yazi
			{ "<leader>-", desc = "Yazi" },

			-- bufferline
			{ "<leader>1", "<cmd>BufferLineGoToBuffer 1<CR>", desc = "Goto Tab1" },
			{ "<leader>2", "<cmd>BufferLineGoToBuffer 2<CR>", desc = "Goto Tab2" },
			{ "<leader>3", "<cmd>BufferLineGoToBuffer 3<CR>", desc = "Goto Tab3" },
			{ "<leader>4", "<cmd>BufferLineGoToBuffer 4<CR>", desc = "Goto Tab4" },
			{ "<leader>5", "<cmd>BufferLineGoToBuffer 5<CR>", desc = "Goto Tab5" },
			-- bufferline - Tab
			{ "<leader>tj", desc = "Goto Next Tab" },
			{ "<leader>tk", desc = "Goto Previous Tab" },
			{ "<leader>tp", desc = "Pick Tab" },
			{ "<leader>td", desc = "Close Tab" },
			-- bufferline - Close Tab
			{ "<leader>tc", group = "Close" },
			{ "<leader>tcp", desc = "Pick And Close Tab" },
			{ "<leader>tco", desc = "Close Other Tabs" },
			{ "<leader>tcl", desc = "Close Left Tab" },
			{ "<leader>tcr", desc = "Close Right Tab" },
			-- arena
			{"<leader>tm", "<cmd>ArenaToggle<cr>", desc = "Toggle Buffer Menu" },

			-- File
			{ "<leader>f", group = "File" },
			{ "<leader>fB", "<cmd>FzfLua buffers<cr>", desc = "Buffers(All)" },
			{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files(Root)" },
			{ "<leader>fF", "<cmd>lua require('fzf-lua').files({ cwd = vim.fn.expand('%:p:h') })<cr>", desc = "Find Files(Buffer Dir)" },
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
			-- File -> Wrapping
			{ "<leader>fR", group = "Wrapping" },
			{ "<leader>fRs", "<cmd>lua require('wrapping').soft_wrap_mode()<cr>", desc = "Soft Wrap Mode" },
			{ "<leader>fRh", "<cmd>lua require('wrapping').hard_wrap_mode()<cr>", desc = "Hard Wrap Mode" },
			{ "<leader>fRt", "<cmd>lua require('wrapping').toggle_wrap_mode()<cr>", desc = "Toggle Wrap Mode" },
			-- File -> linter
			{ "<leader>fL", "<cmd>lua require('lint').try_lint()<cr>", desc = "Trigger linting" },

			-- Terminal
			{ "<leader>t", group = "Terminal/Tab" },
			{ "<leader>tf", desc = "Terminal Float" },
			{ "<leader>th", desc = "Terminal Horizontal" },
			{ "<leader>tv", desc = "Terminal Vertical " },
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
			{ "<leader>gS", "<cmd>lua require 'gitsigns'.stage_buffer()<cr>", desc = "Stage Hunk" },
			{ "<leader>gu", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", desc = "Undo Stage Hunk" },
			{ "<leader>gU", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", desc = "Undo Stage Hunk" },
			{ "<leader>go", "<cmd>FzfLua git_status<cr>", desc = "Open changed file" },
			{ "<leader>gb", "<cmd>FzfLua git_branches<cr>", desc = "Checkout branch" },
			{ "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Checkout commit" },
			{ "<leader>gd", "<cmd>Gitsigns diffthis HEAD<cr>", desc = "Diffthis" },

			-- diagonostics
			{ "<leader>a", group = "Diagonostics" },
			{
				"<leader>ao",
				"<cmd>lua vim.diagnostic.open_float(nil, {focus=false, scope='cursor', border='rounded'})<cr>",
				desc = "Show Diagonostics",
			},
			{
				"<leader>ap",
				"<cmd>lua vim.diagnostic.goto_prev({float={source=true, border='rounded'}})<cr>",
				desc = "Previous Diagonostics",
			},
			{
				"<leader>an",
				"<cmd>lua vim.diagnostic.goto_next({float={source=true, border='rounded'}})<cr>",
				desc = "Next Diagonostics",
			},
			{
				"<leader>al",
				"<cmd>lua vim.diagnostic.setloclist()<cr>",
				desc = "Diagonostics Location",
			},

			{ "<leader>ac", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics(Buffer)" },
			{ "<leader>ar", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Diagnostics(Workspace)" },

			-- Dap
			{ "<leader>d", group = "Dap" },
			{ "<leader>dB", desc = "BreakPoint Condition" },
			{ "<leader>db", desc = "Toggle BreakPoint" },
			{ "<leader>dc", desc = "Continue " },
			{ "<leader>dC", desc = "Run to Cursor" },
			{ "<leader>da", desc = "Run with Args" },
			{ "<leader>dl", desc = "Run Last" },
			{ "<leader>dg", desc = "Goto line (on execute)" },
			{ "<leader>dp", desc = "Pause" },
			{ "<leader>ds", desc = "Session " },
			{ "<leader>dr", desc = "Toggle REPL" },
			{ "<leader>do", desc = "Step Out" },
			{ "<leader>dO", desc = "Step Over" },
			{ "<leader>di", desc = "Step Into" },
			{ "<leader>dj", desc = "Down" },
			{ "<leader>dk", desc = "Up" },
			{ "<leader>dw", desc = "Widgets" },
			{ "<leader>du", desc = "Dap UI" },
			{ "<leader>de", desc = "Dap Eval " },

			-- Neotest
			{ "<leader>v", group = "Neotest" },
			{ "<leader>va", "<cmd>lua require('neotest').run.attach()<cr>", desc = "Attach Nearest" },
			{ "<leader>vd", "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", desc = "Debug Nearest" },
			{ "<leader>vt", "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<cr>", desc = "Run File" },
			{ "<leader>vT", "<cmd>lua require('neotest').run.run(vim.uv.cwd())<cr>", desc = "Run All Test Files" },
			{ "<leader>vr", "<cmd>lua require('neotest').run.run()<cr>", desc = "Run Nearest" },
			{ "<leader>vl", "<cmd>lua require('neotest').run.run_last()<cr>", desc = "Run Last" },
			{ "<leader>vs", "<cmd>lua require('neotest').summary.toggle()<cr>", desc = "Toggle Summary" },
			{
				"<leader>vo",
				"<cmd>lua require('neotest').output.open({ enter = true, auto_close = true })<cr>",
				desc = "Show Output",
			},
			{ "<leader>vO", "<cmd>lua require('neotest').output_panel.toggle()<cr>", desc = "Toggle Output Panel" },
			{ "<leader>vS", "<cmd>lua require('neotest').run.stop()<cr>", desc = "Stop" },

			{ "<leader>M", group = "Makers" },
			{ "<leader>Mg", group = "Groups" },

			-- CscopeMaps registers <leader>m* itself with which-key (group "cscope").
			-- Don't redeclare here; doing so triggers a duplicate-mapping warning.

			-- LSP
			{ "<leader>k", group = "LSP" },
			{ "<leader>kt", desc = "Toggle Signature" },
			{ "<leader>kh", desc = "Hover LSP Info" },
			{ "<leader>kq", desc = "Quit LSP Floating Windows" },
			{ "<leader>kr", "<cmd>FzfLua lsp_references<cr>", desc = "References" },
			{ "<leader>ki", "<cmd>FzfLua lsp_incoming_calls<cr>", desc = "Incoming Calls" },
			{ "<leader>ko", "<cmd>FzfLua lsp_outgoing_calls<cr>", desc = "Outgoing Calls" },
			{ "<leader>kd", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols(Buffer)" },
			{ "<leader>kw", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
			{ "<leader>kW", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", desc = "Workspace Symbols(Live)" },
			{ "<leader>kI", "<cmd>FzfLua lsp_implementations<cr>", desc = "Implementation" },
			{ "<leader>kD", "<cmd>FzfLua lsp_definitions<cr>", desc = "Definitions" },
			{ "<leader>kT", "<cmd>FzfLua lsp_typedefs<cr>", desc = "Type Definitions" },

			-- Rust
			{ "<leader>R", group = "Rust" },
			{ "<leader>RD", "<cmd>RustLsp debuggables<cr>", desc = "Rust Debuggables" },
			{ "<leader>RR", "<cmd>RustLsp runnables<cr>", desc = "Rust Runnables" },
			{ "<leader>RT", "<cmd>RustLsp testables<cr>", desc = "Rust Testables" },
			{ "<leader>Re", "<cmd>RustLsp expandMacro<cr>", desc = "Expand Macro" },
			{ "<leader>Rb", "<cmd>RustLsp rebuildProcMacros<cr>", desc = "Rebuild ProcMacros" },
			{ "<leader>Ru", "<cmd>RustLsp moveItem up<cr>", desc = "Move item up" },
			{ "<leader>Rd", "<cmd>RustLsp moveItem down<cr>", desc = "Move item down" },
			{ "<leader>Ra", "<cmd>RustLsp codeAction<cr>", desc = "Code Action" },
			{ "<leader>Rh", "<cmd>RustLsp hover actions<cr>", desc = "Hover Actions" },
			{ "<leader>Rn", "<cmd>RustLsp hover range<cr>", desc = "Hover Range" },
			{ "<leader>RE", "<cmd>RustLsp explainError<cr>", desc = "Explain Error" },
			{ "<leader>Rr", "<cmd>RustLsp renderDiagnostic<cr>", desc = "Render Diagnostic" },
			{ "<leader>Ro", "<cmd>RustLsp openCargo<cr>", desc = "Open cargo" },
			{ "<leader>RO", "<cmd>RustLsp openDocs<cr>", desc = "Open docs.rs documentation" },
			{ "<leader>Rp", "<cmd>RustLsp parentModule<cr>", desc = "Rust parent module" },
			{ "<leader>Rj", "<cmd>RustLsp joinLines<cr>", desc = "Join lines" },
			{ "<leader>RS", "<cmd>RustLsp ssr<cr>", desc = "Structural search Replace" },
			{ "<leader>Rg", "<cmd>RustLsp crateGraph<cr>", desc = "View create graph" },
			{ "<leader>Rt", "<cmd>RustLsp syntaxTree<cr>", desc = "Rust syntax tree" },
			{ "<leader>Rv", "<cmd>RustLsp view hir<cr>", desc = "View rust HIR" },
			{ "<leader>RV", "<cmd>RustLsp vim mir<cr>", desc = "View rust MIR" },
			-- Rust -> workspace symbol
			{ "<leader>Rs", group = "WorkspaceSymbol" },
			{ "<leader>Rst", "<cmd>RustLsp workspaceSymbol onlyTypes<cr>", desc = "Only type symbols" },
			{ "<leader>Rsa", "<cmd>RustLsp workspaceSymbol allSymbols<cr>", desc = "Show all symbols" },
			-- Rust -> FlyCheck
			{ "<leader>Rf", group = "FlyCheck" },
			{ "<leader>Rfr", "<cmd>RustLsp flyCheck run<cr>", desc = "Run check" },
			{ "<leader>Rfc", "<cmd>RustLsp flyCheck clear<cr>", desc = "Clear check" },
			{ "<leader>Rfn", "<cmd>RustLsp flyCheck cancel<cr>", desc = "Cancel check" },
			-- Crates
			{ "<leader>C", group = "Crates" },
			{ "<leader>Ct", "<cmd>lua require('crates').toggle()<cr>", desc = "Toggle" },
			{ "<leader>Cr", "<cmd>lua require('crates').reload()<cr>", desc = "Reload" },
			{ "<leader>Cv", "<cmd>lua require('crates').show_versions_popup()<cr>", desc = "Show versions" },
			{ "<leader>Cf", "<cmd>lua require('crates').show_features_popup()<cr>", desc = "Show features" },
			{ "<leader>Cd", "<cmd>lua require('crates').show_dependencies_popup()<cr>", desc = "Show dependencies" },
			{ "<leader>Ca", "<cmd>lua require('crates').update_all_crates()<cr>", desc = "Update all crates" },
			{ "<leader>CA", "<cmd>lua require('crates').upgrade_all_crates()<cr>", desc = "Upgrade all crates" },
			{
				"<leader>Cx",
				"<cmd>lua require('crates').expand_plain_crate_to_inline_table()<cr>",
				desc = "Expand plain create to inline table",
			},
			{
				"<leader>CX",
				"<cmd>lua require('crates').extract_crate_into_table()<cr>",
				desc = "Extract create into table",
			},
			{ "<leader>CH", "<cmd>lua require('crates').open_homepage()<cr>", desc = "Open homepage" },
			{ "<leader>CR", "<cmd>lua require('crates').open_repository()<cr>", desc = "Open repository" },
			{ "<leader>CD", "<cmd>lua require('crates').open_documentation()<cr>", desc = "Open documentation" },
			{ "<leader>CC", "<cmd>lua require('crates').open_crates_io()<cr>", desc = "Open crates io" },
			{ "<leader>Cu", "<cmd>lua require('crates').update_crate()<cr>", desc = "Update crate" },
			{ "<leader>CU", "<cmd>lua require('crates').upgrade_crate()<cr>", desc = "Upgrade crate" },
		})
	end,
}
