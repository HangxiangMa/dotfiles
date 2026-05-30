local Crisp = {}

function Crisp.notifyLSPError()
	return not os.getenv("NVIM_NOT_NOTIFY_LSP_ERROR")
end

function Crisp.prequire(module)
	local ok, result = pcall(require, module)
	if ok then
		return result
	else
		return nil
	end
end

function Crisp.isBigFile(bufnr)
	local maxSize = 1024 * 1024 -- 1MB
	local maxLine = 2048
	local lineCount = vim.api.nvim_buf_line_count(bufnr)
	if lineCount > maxLine then
		return true
	end
	local ok, stats = pcall((vim.uv or vim.loop).fs_stat, vim.api.nvim_buf_get_name(bufnr))
	if ok and stats and stats.size > maxSize then
		return true
	end
	return false
end

Crisp.notify = function(msg, level, title)
	-- Route through vim.notify; snacks.notifier (or nvim-notify, if installed)
	-- will pick this up. Avoids hard-depending on a specific notification UI.
	vim.notify(msg, level, { title = title, timeout = 1000 })
end

Crisp.info = function(msg, title)
	Crisp.notify(msg, vim.log.levels.INFO, title)
end

Crisp.warn = function(msg, title)
	Crisp.notify(msg, vim.log.levels.WARN, title)
end

Crisp.error = function(msg, title)
	Crisp.notify(msg, vim.log.levels.ERROR, title)
end

Crisp.setKeymap = function(mode, lhs, rhs, opts)
	opts = vim.tbl_extend("keep", opts or {}, { noremap = true, silent = true })
	vim.keymap.set(mode, lhs, rhs, opts)
end

Crisp.setBufKeymap = function(buffer, mode, lhs, rhs, opts)
	opts = vim.tbl_extend("keep", opts or {}, { noremap = true, silent = true })
	opts.buffer = buffer
	vim.keymap.set(mode, lhs, rhs, opts)
end

Crisp.createAutocmd = vim.api.nvim_create_autocmd
Crisp.createCommand = function(command, f, opts)
	vim.api.nvim_create_user_command(command, f, opts or {})
end

return Crisp
