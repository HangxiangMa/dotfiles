-- kclippy: camera-kernel's own C / device-tree lint server, not a package-
-- manager install. Its module (editor/nvim-lsp.lua) lives *inside* whatever
-- camera-kernel checkout you have open — there's no fixed path (the AU_LINUX
-- version directory changes per branch/sync), so it's located by searching
-- upward from the current buffer for the same two markers the module itself
-- uses to find its project root (kclippy.py + editor/nvim-lsp.lua).
--
-- All LSP registration (vim.lsp.config/enable), the nine :Kclippy* commands
-- and the toggle/scope logic live in that module, not here — this file only
-- locates it and calls its setup(), so the behaviour has exactly one source
-- of truth shared with anyone else using nvim-lsp.lua directly (VS Code /
-- Vim / plain-Neovim users get the same server; this is just the SERVERS-
-- table plumbing to fit lsp.lua's custom-server contract).
local server = {}

-- Find the camera-kernel checkout containing the current buffer, if any.
-- Returns the kclippy tool dir (…/internal/kclippy) or nil.
--
-- kclippy lives at <camera-kernel>/internal/kclippy/, which is NOT an ancestor
-- of the driver files under <camera-kernel>/drivers/ — it's a sibling. So
-- searching upward for kclippy.py from a driver buffer never finds it. Instead
-- locate the camera-kernel checkout ROOT (an ancestor of both drivers/ and
-- internal/), then look for internal/kclippy/ under it. `camera_modules.bzl`
-- is a camera-kernel-root-specific marker; `.git` is the fallback. Also handle
-- the case where the buffer is itself inside internal/kclippy/ (editing the
-- tool's own source) by searching upward for kclippy.py first.
local function _valid(dir)
	if dir and vim.fn.filereadable(dir .. "/editor/nvim-lsp.lua") == 1 then
		return dir
	end
	return nil
end

local function find_kclippy_dir(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr or 0)
	if path == "" then
		path = vim.loop.cwd()
	end
	local start = vim.fs.dirname(path)

	-- 1. Buffer is inside internal/kclippy/ itself → kclippy.py is an ancestor.
	local marker = vim.fs.find("kclippy.py", {
		upward = true,
		path = start,
		stop = vim.loop.os_homedir(),
	})[1]
	if marker then
		local hit = _valid(vim.fs.dirname(marker))
		if hit then
			return hit
		end
	end

	-- 2. Buffer is elsewhere in the checkout (e.g. drivers/…): find the
	-- camera-kernel root by an ancestor marker, then internal/kclippy/ under it.
	local root_marker = vim.fs.find({ "camera_modules.bzl", ".git" }, {
		upward = true,
		path = start,
		stop = vim.loop.os_homedir(),
	})[1]
	if root_marker then
		local root = vim.fs.dirname(root_marker)
		local hit = _valid(root .. "/internal/kclippy")
		if hit then
			return hit
		end
	end

	return nil
end

-- checkOK() only asks "is kclippy runnable at all" (kept for parity with
-- clangd.lua/rust.lua's contract, though lsp.lua currently gates on `exe`
-- via vim.fn.executable rather than calling this). Whether a given buffer is
-- actually inside a camera-kernel checkout is a per-buffer question that
-- find_kclippy_dir() (and the FileType-scoped setup below) answers instead —
-- kclippy is never globally enabled the way clangd/rust_analyzer are.
function server.checkOK()
	return vim.fn.executable("kclippy") == 1 or vim.fn.executable("python3") == 1
end

-- Unlike clangd/rust_analyzer (always-on for their filetypes), kclippy only
-- makes sense inside a camera-kernel checkout — so defer the actual
-- dofile+setup to the first c/cpp/dts buffer that turns out to be inside
-- one, rather than unconditionally enabling a "kclippy" config at startup.
-- vim.lsp.enable() self-registers its own FileType autocmd for *future*
-- buffers (verified empirically: calling it once from inside a FileType
-- callback still attaches to the buffer that triggered it, and later
-- buffers in other checkouts attach automatically without calling enable()
-- again) — so this only needs to run mod.setup() a single time, the first
-- time a camera-kernel buffer is seen.
function server.setup()
	local loaded = false
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "c", "cpp", "dts" },
		callback = function(ev)
			if loaded then
				return
			end
			local dir = find_kclippy_dir(ev.buf)
			if not dir then
				return -- not inside a camera-kernel checkout; nothing to do
			end
			if not vim.g.kclippy_cmd then
				-- Prefer a real console-script/PATH install; fall back to
				-- running the checkout's own kclippy.py via python3 so this
				-- works even before `pip install kclippy` / a .pyz symlink.
				if vim.fn.executable("kclippy") == 1 then
					vim.g.kclippy_cmd = "kclippy"
				else
					vim.g.kclippy_cmd = { "python3", dir .. "/kclippy.py" }
				end
			end
			local ok, mod = pcall(dofile, dir .. "/editor/nvim-lsp.lua")
			if not ok then
				vim.notify("kclippy: failed to load " .. dir .. "/editor/nvim-lsp.lua: "
					.. tostring(mod), vim.log.levels.ERROR)
				return
			end
			loaded = true
			mod.setup() -- registers vim.lsp.config/enable('kclippy') + :Kclippy* commands
		end,
	})
end

return server
