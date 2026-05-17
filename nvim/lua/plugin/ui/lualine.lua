local function virtlocation()
	local line = vim.fn.line('.')
	local vcol = vim.fn.virtcol('.')
	local mode = vim.fn.mode()
	local select_info = ""

	if mode:match("[vV\022]") then
		local start_pos = vim.fn.getpos("v")
		local end_pos = vim.fn.getpos(".")
		local start_line, start_col = start_pos[2], start_pos[3]
		local end_line, end_col = end_pos[2], end_pos[3]

		-- start < end
		if start_line > end_line or (start_line == end_line and start_col > end_col) then
			start_line, end_line = end_line, start_line
			start_col, end_col = end_col, start_col
		end

		local count = 0
		local line_count = end_line - start_line + 1

		if mode == 'V' then
			-- Visual Line Mode
			local lines = vim.fn.getline(start_line, end_line)
			for _, text in ipairs(lines) do
				count = count + #text
			end
			count = count + (line_count - 1) -- LF
		elseif mode == "\022" then
			-- Visual Block Mode
			local lines = vim.fn.getline(start_line, end_line)
			for _, text in ipairs(lines) do
				local s_col = math.min(start_col, #text + 1)
				local e_col = math.min(end_col, #text)
				if s_col <= e_col then
					count = count + (e_col - s_col + 1)
				end
			end
			count = count + (line_count - 1) -- LF
		else
			-- Visual Mode
			if start_line == end_line then
				local line_text = vim.fn.getline(start_line)
				count = #string.sub(line_text, start_col, end_col)
			else
				local lines = vim.fn.getline(start_line, end_line)
				for i, text in ipairs(lines) do
					if i == 1 then
						count = count + #string.sub(text, start_col)
					elseif i == #lines then
						count = count + #string.sub(text, 1, end_col)
					else
						count = count + #text
					end
				end
				count = count + (line_count - 1) -- LF
			end
		end

		select_info = string.format("%d:%d Sel:%d|%d", line, vcol, count, line_count)
	else
		select_info = string.format("%d:%d", line, vcol)
	end

	return select_info
end


-- status bar
return {
	"nvim-lualine/lualine.nvim",
	lazy = false,
	dependencies = { "nvim-tree/nvim-web-devicons", lazy = false },
	init = function()
		vim.g.lualine_laststatus = vim.o.laststatus
		if vim.fn.argc(-1) > 0 then
			-- set an empty statusline till lualine loads
			vim.o.statusline = " "
		else
			-- hide the statusline on the starter page
			vim.o.laststatus = 0
		end
	end,
	config = function()
		-- local navic = require("nvim-navic")
		local config = {
			options = {
				icons_enabled = true,
				theme = "auto",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {
						"help",
						"alpha",
						"dashboard",
						"NvimTree",
						"neo-tree",
						"trouble",
						"lazy",
						"mason",
						"notify",
						"toggleterm",
						"lazyterm",
						"neominimap",
					},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				refresh = {
					statusline = 1000,
					tabline = 1000,
					winbar = 1000,
				},
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				lualine_c = {},
				lualine_x = {
					{
						"encoding",
						fmt = function(str)
							return string.upper(str)
						end
					}
					, "fileformat", "filetype"
				},
				lualine_y = { "progress" },
				lualine_z = { virtlocation, { "datetime", style = " %H:%M" } },
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = { virtlocation, { "datetime", style = " %H:%M" } },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {
				-- lualine_c = {
				-- 	{
				-- 		"navic",
				-- 		color_correction = nil,
				-- 		navic_opts = nil
				-- 	}
				-- },
			},
			inactive_winbar = {},
			extensions = {},
		}

		-- Inserts a component in lualine_c at left section
		local function ins_left(component)
			table.insert(config.sections.lualine_c, component)
		end

		-- Insert mid section. You can make any number of sections in neovim :)
		-- for lualine it's any number greater then 2
		ins_left({
			function()
				return "%="
			end,
		})

		ins_left({
			-- Lsp server name .
			function()
				local msg = "No Active Lsp"
				local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
				local clients = vim.lsp.get_clients()
				if next(clients) == nil then
					return msg
				end
				for _, client in ipairs(clients) do
					local filetypes = client.config.filetypes
					if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
						return client.name
					end
				end
				return msg
			end,
			icon = " LSP:",
			color = { fg = "#eeeeee", gui = "bold" },
		})

		-- Now don't forget to initialize lualine
		require("lualine").setup(config)
	end,
}
