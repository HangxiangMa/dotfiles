-- Guarantee a modern `node` on the PATH we hand to spawned LSP servers.
--
-- The mason bash-language-server launcher starts with `#!/usr/bin/env node`,
-- so PATH order alone decides which node runs it. Inside tmux the server env
-- can predate nvm, so `node` resolves to the system /usr/bin/node (v12) -- too
-- old to even parse the server's optional-chaining (`?.`) syntax, so it crashes
-- the moment it loads with "SyntaxError: Unexpected token '.'" and the client
-- exits with code 1. We prepend the newest nvm node, but only when the visible
-- node is missing or older than MIN_MAJOR, so an explicit `nvm use <version>`
-- (even an older one) is never overridden.

local MIN_MAJOR = 16

-- Major version of a node executable. Prefer parsing the nvm-style path so the
-- healthy case costs no fork; only shell out for a node whose path carries no
-- version (e.g. /usr/bin/node), which is exactly the case we mean to replace.
local function major_of(node)
	local from_path = node:match("/node/v(%d+)%.")
	if from_path then
		return tonumber(from_path)
	end
	local out = vim.fn.system({ node, "--version" }) -- "vXX.Y.Z\n"
	return tonumber(out:match("^v(%d+)%."))
end

-- bin dir of the highest-versioned node install under nvm, or nil if none.
local function newest_nvm_bin()
	local nvm = vim.env.NVM_DIR
	if not nvm or nvm == "" then
		nvm = (vim.env.HOME or "") .. "/.nvm"
	end
	local best_bin, best_key
	for _, bin in ipairs(vim.fn.glob(nvm .. "/versions/node/v*/bin", true, true)) do
		local a, b, c = bin:match("/v(%d+)%.(%d+)%.(%d+)/bin$")
		if a then
			-- zero-padded so a plain string compare orders versions numerically
			local key = string.format("%05d%05d%05d", a, b, c)
			if not best_key or key > best_key then
				best_key, best_bin = key, bin
			end
		end
	end
	return best_bin
end

local node = vim.fn.exepath("node")
if node == "" or (major_of(node) or 0) < MIN_MAJOR then
	local bin = newest_nvm_bin()
	-- Only intervene if nvm actually offers something new enough; otherwise
	-- leave PATH untouched rather than swap one unusable node for another.
	if bin and (tonumber(bin:match("/v(%d+)%.")) or 0) >= MIN_MAJOR then
		vim.env.PATH = bin .. ":" .. (vim.env.PATH or "")
	end
end
