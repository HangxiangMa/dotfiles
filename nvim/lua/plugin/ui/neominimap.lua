return {
	"Isrothy/neominimap.nvim",
	version = "^v3",
	enabled = true,
	lazy = false, -- NOTE: NO NEED to Lazy load
	init = function()
		-- The following options are recommended when layout == "float"
		vim.opt.wrap = false
		vim.opt.sidescrolloff = 36 -- Set a large value

		--- Put your configuration here
		---@type Neominimap.UserConfig
		vim.g.neominimap = {
			auto_enable = true,

			exclude_filetypes = {
				"help",
				"bigfile", -- For Snacks.nvim
				"markdown",
			},

			-- Minimap will not be created for buffers of these types
			exclude_buftypes = {
				"nofile",
				"nowrite",
				"quickfix",
				"terminal",
				"prompt",
			},

			layout = "float", ---@type Neominimap.Config.LayoutType

			--- Used when `layout` is set to `split`
			split = {
				minimap_width = 20, ---@type integer
				fix_width = true, ---@type boolean
				direction = "right", ---@type Neominimap.Config.SplitDirection
				close_if_last_window = true, ---@type boolean
			},

			float = {
				-- zindex: https://github.com/neovim/neovim/issues/18486
				-- need to be higher than 'nvim-treesiter-context'
				z_index = 11,
			},

			tab_filter = function(tab_id)
				local function is_float_window(win_id)
					local win_config = vim.api.nvim_win_get_config(win_id)
					return win_config.relative ~= ""
				end
				local win_list = vim.api.nvim_tabpage_list_wins(tab_id)
				local exclude_ft = {
					"qf",
					"trouble",
					"neo-tree",
					"alpha",
					"neominimap",
					"snacks_dashboard",
					"toggleterm",
					"help",
					"bigfile",
					"NvimTree",
					"startup",
					"lazy",
					"mason",
					"notify",
					"",
				}
				for _, win_id in ipairs(win_list) do
					if not is_float_window(win_id) then
						local bufnr = vim.api.nvim_win_get_buf(win_id)
						if not vim.tbl_contains(exclude_ft, vim.bo[bufnr].filetype) then
							return true
						end
					end
				end
				return false
			end,
		}
	end,
}
