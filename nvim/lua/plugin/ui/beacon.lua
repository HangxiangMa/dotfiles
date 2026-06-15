return {
	"danilamihailov/beacon.nvim",
	opts = {
		speed = 5,
		fps = 30,
		enabled = function()
			if vim.g.beacon_enabled == false then
				return false
			end
			-- Skip the fade animation on big buffers: each frame triggers a
			-- full redraw, which is what makes large files feel laggy.
			local buf = vim.api.nvim_get_current_buf()
			if vim.api.nvim_buf_line_count(buf) > 5000 then
				return false
			end
			local ok, bytes = pcall(vim.api.nvim_buf_get_offset, buf, vim.api.nvim_buf_line_count(buf))
			if ok and bytes > 1024 * 1024 then
				return false
			end
			return true
		end,
	},
	config = function(_, opts)
		require("beacon").setup(opts)

		local jump_times = {}
		local suppress_timer = nil
		vim.g.beacon_enabled = true

		vim.api.nvim_create_autocmd("CursorMoved", {
			group = vim.api.nvim_create_augroup("beacon_throttle", { clear = true }),
			callback = function()
				local now = vim.loop.hrtime() / 1e6
				table.insert(jump_times, now)
				if #jump_times > 3 then
					table.remove(jump_times, 1)
				end

				if #jump_times >= 3 and (now - jump_times[1]) < 500 then
					vim.g.beacon_enabled = false
					if suppress_timer then
						vim.fn.timer_stop(suppress_timer)
					end
					suppress_timer = vim.fn.timer_start(1000, function()
						suppress_timer = nil
						vim.g.beacon_enabled = true
					end)
				end
			end,
		})
	end,
}
