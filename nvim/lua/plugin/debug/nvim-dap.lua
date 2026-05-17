---@param config {args?:string[]|fun():string[]?}
local function get_args(config)
	local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
	config = vim.deepcopy(config)
	---@cast args string[]
	config.args = function()
		local new_args = vim.fn.input("Run with args: ", table.concat(args, " ")) --[[@as string]]
		return vim.split(vim.fn.expand(new_args) --[[@as string]], " ")
	end
	return config
end

local function check_utils()
	local crisp = require("core.crisp")
	local script = [[
        #!/bin/bash
        package_installed=true
        if ! python3 -m list | grep debugpy &>/dev/null; then
            echo "python module 'debugpy' not installed"
            package_installed=false
        fi

        if "$package_installed" = false; then
            echo -n "Please run 'requirements.sh' to install 'debug-tools' dependencies first"
        fi
    ]]
	local handle = io.popen("bash -c '" .. script:gsub("'", "'\\''") .. "'", "r")
	if handle ~= nil then
		local result = handle:read("*a")
		handle:close()
		if result ~= nil and result ~= "" then
			crisp.notify(result, "error", "Package state checker information")
		end
	end
end

---@warning Before you use the Dap Debugger, you need to ensure to add symbol table and debugger info while compiling.
---         eg. g++ -std=c++17 test.cpp -g -o test
return {
	{
		"mfussenegger/nvim-dap",
		enabled = false,
		lazy = true,
		dependencies = {
			{ "rcarriga/nvim-dap-ui" },
			{ "theHamsta/nvim-dap-virtual-text" },
			{
				"jay-babu/mason-nvim-dap.nvim",
				dependencies = {
					"williamboman/mason.nvim",
					"mfussenegger/nvim-dap",
				},
				config = function()
					require("mason-nvim-dap").setup({
						ensure_installed = {
							"bash",
							"python",
							"codelldb",
							"cpptools",
						},
						automatic_installation = true,
					})
				end,
			},
		},
		keys = {
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "Breakpoint Condition",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Continue",
			},
			{
				"<leader>da",
				function()
					require("dap").continue({ before = get_args })
				end,
				desc = "Run with Args",
			},
			{
				"<leader>dC",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "Run to Cursor",
			},
			{
				"<leader>dg",
				function()
					require("dap").goto_()
				end,
				desc = "Go to line (no execute)",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Step Into",
			},
			{
				"<leader>dj",
				function()
					require("dap").down()
				end,
				desc = "Down",
			},
			{
				"<leader>dk",
				function()
					require("dap").up()
				end,
				desc = "Up",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Run Last",
			},
			{
				"<leader>do",
				function()
					require("dap").step_out()
				end,
				desc = "Step Out",
			},
			{
				"<leader>dO",
				function()
					require("dap").step_over()
				end,
				desc = "Step Over",
			},
			{
				"<leader>dp",
				function()
					require("dap").pause()
				end,
				desc = "Pause",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Toggle REPL",
			},
			{
				"<leader>ds",
				function()
					require("dap").session()
				end,
				desc = "Session",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>dw",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "Widgets",
			},
		},
		build = function()
			check_utils()
		end,
		config = function()
			-- load from json file
			require("dap.ext.vscode").load_launchjs()
			local dap = require("dap")
			-- config adapters
			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = os.getenv("HOME") .. "/.local/share/nvim/mason/bin/codelldb",
					args = { "--port", "${port}" },
				},
			}
			dap.adapters.cppdbg = {
				id = "cppdbg",
				type = "executable",
				command = os.getenv("HOME") .. "/.local/share/nvim/mason/bin/OpenDebugAD7",
			}
			dap.adapters.nlua = {
				type = "server",
				host = "127.0.0.1",
				port = "8086",
			}

			-- https://github.com/mfussenegger/nvim-dap/discussions/533
			-- path to python.exe of reference debugpy, installed in the (base) environment in anaconda
			local std_debugpy_python = vim.fn.environ()["CONDA_PYTHON_EXE"]
			if not std_debugpy_python then
				std_debugpy_python = "/usr/bin/python3"
			end
			dap.adapters.python = {
				type = "executable",
				command = std_debugpy_python,
				args = { "-m", "debugpy.adapter" },
			}

			-- config language
			dap.configurations.lua = {
				{
					type = "nlua",
					request = "attach",
					name = "Attach to running Neovim instance (port = 8086)",
				},
			}
			dap.configurations.cpp = {
				{
					name = "Launch",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},

					-- 💀
					-- if you change `runInTerminal` to true, you might need to change the yama/ptrace_scope setting:
					--
					--    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
					--
					-- Otherwise you might get the following error:
					--
					--    Error on launch: Failed to attach to the target process
					--
					-- But you should be aware of the implications:
					-- https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
					-- runInTerminal = false,
				},
				{
					type = "codelldb",
					request = "attach",
					name = "Attach to process",
					processId = require("dap.utils").pick_process,
					cwd = "${workspaceFolder}",
				},
			}
			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp
			dap.configurations.python = {
				{
					name = "Python: Launch module",
					type = "python",
					request = "launch",
					console = "integratedTerminal",
					program = function()
						return vim.fn.input("Python program path: ", vim.fn.getcwd() .. "/", "file")
					end,
					python = function()
						if vim.fn.environ()["CONDA_DEFAULT_ENV"] ~= "base" then
							local active_python = vim.fn.environ()["CONDA_PREFIX"] .. "/bin/python"
							local yes_no_active_python =
								vim.fn.input("Use active python binary (" .. active_python .. ")? (y/n) ")
							if yes_no_active_python == "n" or yes_no_active_python == "N" then
								local yes_no_default_python =
									vim.fn.input("Use default python (" .. std_debugpy_python .. ")? (y/n) ")
								if yes_no_default_python == "n" or yes_no_default_python == "N" then
									-- python from user given path
									return vim.fn.input("Input python binary path (cwd is " .. vim.fn.getcwd() .. "): ")
								else
									-- python.exe from base anaconda environment
									return std_debugpy_python
								end
							else
								-- python.exe from active anaconda environment
								return active_python
							end
						else
							local yes_no_default_python =
								vim.fn.input("Use default python (" .. std_debugpy_python .. ")? (y/n) ")
							if yes_no_default_python == "n" or yes_no_default_python == "N" then
								-- python.exe from user given path
								return vim.fn.input("Input python binary path (cwd is " .. vim.fn.getcwd() .. "): ")
							else
								-- python.exe from base anaconda environment
								return std_debugpy_python
							end
						end
					end,
				},
			}
		end,
	},
}
