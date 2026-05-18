-- :TmuxCapture [target] — snapshot a tmux pane into the quickfix list.
-- target defaults to "{last}" (the previously active pane). Examples:
--   :TmuxCapture            capture {last}
--   :TmuxCapture {right-of} capture neighbour to the right
--   :TmuxCapture %12        capture pane id %12
--
-- Errorformat covers gcc/clang/python tracebacks; unmatched lines
-- still appear in the quickfix list as plain text so nothing is lost.

local function capture(target)
	if vim.env.TMUX == nil or vim.env.TMUX == "" then
		vim.notify("TmuxCapture: not inside a tmux session", vim.log.levels.WARN)
		return
	end
	target = (target and target ~= "") and target or "{last}"
	-- -p print to stdout, -J join wrapped lines, -S -32768 grab full scrollback
	local out = vim.fn.systemlist({ "tmux", "capture-pane", "-p", "-J", "-S", "-32768", "-t", target })
	if vim.v.shell_error ~= 0 then
		vim.notify("TmuxCapture: tmux failed for target " .. target, vim.log.levels.ERROR)
		return
	end
	while #out > 0 and out[#out]:match("^%s*$") do
		table.remove(out)
	end
	if #out == 0 then
		vim.notify("TmuxCapture: pane " .. target .. " is empty", vim.log.levels.INFO)
		return
	end
	local efm = table.concat({
		"%f:%l:%c: %t%*[^:]: %m",
		"%f:%l:%c: %m",
		"%f:%l: %t%*[^:]: %m",
		"%f:%l: %m",
		'  File "%f"%.%#line %l%.%#',
		"%-G%.%#",
	}, ",")
	vim.fn.setqflist({}, " ", {
		title = "tmux:" .. target,
		lines = out,
		efm = efm,
	})
	vim.cmd("botright copen")
end

vim.api.nvim_create_user_command("TmuxCapture", function(opts)
	capture(opts.args)
end, { nargs = "?", desc = "Capture a tmux pane into the quickfix list" })
