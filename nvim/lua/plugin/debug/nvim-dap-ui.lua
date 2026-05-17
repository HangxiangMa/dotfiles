local dap_breakpoint_color = {
	breakpoint = {
		ctermbg = 0,
		fg = "#993939",
		bg = "#31353f",
	},
	logpoing = {
		ctermbg = 0,
		fg = "#61afef",
		bg = "#31353f",
	},
	stopped = {
		ctermbg = 0,
		fg = "#98c379",
		bg = "#31353f",
	},
}

local dap_breakpoint = {
	error = {
		text = "",
		texthl = "DapBreakpoint",
		linehl = "DapBreakpoint",
		numhl = "DapBreakpoint",
	},
	condition = {
		text = "ﳁ",
		texthl = "DapBreakpoint",
		linehl = "DapBreakpoint",
		numhl = "DapBreakpoint",
	},
	rejected = {
		text = "",
		texthl = "DapBreakpint",
		linehl = "DapBreakpoint",
		numhl = "DapBreakpoint",
	},
	logpoint = {
		text = "",
		texthl = "DapLogPoint",
		linehl = "DapLogPoint",
		numhl = "DapLogPoint",
	},
	stopped = {
		text = "",
		texthl = "DapStopped",
		linehl = "DapStopped",
		numhl = "DapStopped",
	},
}

-- fancy UI for the debugger
return {
	"rcarriga/nvim-dap-ui",
	enabled = false,
	dependencies = {
		"mfussenegger/nvim-dap",
		"nvim-neotest/nvim-nio",
	},
	lazy = true,
	-- stylua: ignore
	keys = {
		{ "<leader>du", function() require("dapui").toggle({}) end, desc = "Dap UI" },
		{ "<leader>de", function() require("dapui").eval() end,     desc = "Dap Eval", mode = { "n", "v" } },
	},
	opts = {},
	config = function(_, opts)
		-- highlight
		vim.api.nvim_set_hl(0, "DapBreakpoint", dap_breakpoint_color.breakpoint)
		vim.api.nvim_set_hl(0, "DapLogPoint", dap_breakpoint_color.logpoing)
		vim.api.nvim_set_hl(0, "DapStopped", dap_breakpoint_color.stopped)
		-- sign
		vim.fn.sign_define("DapBreakpoint", dap_breakpoint.error)
		vim.fn.sign_define("DapBreakpointCondition", dap_breakpoint.condition)
		vim.fn.sign_define("DapBreakpointRejected", dap_breakpoint.rejected)
		vim.fn.sign_define("DapLogPoint", dap_breakpoint.logpoint)
		vim.fn.sign_define("DapStopped", dap_breakpoint.stopped)
		-- setup dap config by VsCode launch.json file
		-- require("dap.ext.vscode").load_launchjs()
		local dap = require("dap")
		local dapui = require("dapui")
		dapui.setup(opts)
		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open({})
		end
		dap.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close({})
			dap.repl.close()
		end
		dap.listeners.before.event_exited["dapui_config"] = function()
			dapui.close({})
			dap.repl.close()
		end
	end,
}
