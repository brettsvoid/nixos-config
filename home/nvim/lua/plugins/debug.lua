---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_args(config)
	local args = type(config.args) == "function" and (config.args() or {}) or config.args or {} --[[@as string[] | string ]]
	local args_str = type(args) == "table" and table.concat(args, " ") or args --[[@as string]]

	config = vim.deepcopy(config)
	---@cast args string[]
	config.args = function()
		local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str)) --[[@as string]]
		if config.type and config.type == "java" then
			---@diagnostic disable-next-line: return-type-mismatch
			return new_args
		end
		return require("dap.utils").splitstr(new_args)
	end
	return config
end

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		-- Creates a beautiful debugger UI
		"rcarriga/nvim-dap-ui",

		-- Virtual text for the debugger
		{ "theHamsta/nvim-dap-virtual-text", opts = {} },

		-- Required dependency for nvim-dap-ui
		"nvim-neotest/nvim-nio",

		-- Installs the debug adapters for you
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",

		-- Add your own debuggers here
		"leoluz/nvim-dap-go",
		"mxsdev/nvim-dap-vscode-js", -- typescript
		"mfussenegger/nvim-dap-python", -- python
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		require("mason-nvim-dap").setup({
			-- Makes a best effort to setup the various debuggers with
			-- reasonable debug configurations
			automatic_installation = true,

			-- You can provide additional configuration to the handlers,
			-- see mason-nvim-dap README for more information
			handlers = {},

			-- You'll need to check that you have the required things installed
			-- online, please don't ask me how to install them :)
			ensure_installed = {
				-- Update this to ensure that you have the debuggers for the langs you want
			},
		})

		vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

		vim.keymap.set("n", "<leader>da", function()
			dap.continue({ before = get_args })
		end, { desc = "Debug: Run with args" })
		vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
		vim.keymap.set("n", "<leader>dB", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Debug: Breakpoint Condition" })
		vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Run/Continue" })
		vim.keymap.set("n", "<leader>dC", dap.run_to_cursor, { desc = "Debug: Run to cursor" })
		vim.keymap.set("n", "<leader>dg", dap.goto_, { desc = "Debug: Go to line (No execute)" })
		vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step into" })
		vim.keymap.set("n", "<S-l>", dap.step_into, { desc = "Debug: Step into" })
		vim.keymap.set("n", "<leader>dj", dap.down, { desc = "Debug: Down" })
		vim.keymap.set("n", "<S-j>", dap.down, { desc = "Debug: Down" })
		vim.keymap.set("n", "<leader>dk", dap.up, { desc = "Debug: Up" })
		vim.keymap.set("n", "<S-k>", dap.up, { desc = "Debug: Up" })
		vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run last" })
		vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Debug: Step out" })
		vim.keymap.set("n", "<S-h>", dap.step_out, { desc = "Debug: Step out" })
		vim.keymap.set("n", "<leader>dO", dap.step_over, { desc = "Debug: Step over" })
		vim.keymap.set("n", "<leader>dP", dap.pause, { desc = "Debug: Pause" })
		vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "Debug: Toggle repl" })
		vim.keymap.set("n", "<leader>ds", dap.session, { desc = "Debug: Session" })
		vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: Terminate" })
		vim.keymap.set("n", "<leader>dw", require("dap.ui.widgets").hover, { desc = "Debug: Widgets" })

		-- Dap UI setup
		-- For more information, see |:help nvim-dap-ui|
		dapui.setup({
			-- Set icons to characters that are more likely to work in every terminal.
			--    Feel free to remove or use ones that you like more! :)
			--    Don't feel like these are good choices.
			icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
			controls = {
				icons = {
					pause = "⏸",
					play = "▶",
					step_into = "⏎",
					step_over = "⏭",
					step_out = "⏮",
					step_back = "b",
					run_last = "▶▶",
					terminate = "⏹",
					disconnect = "⏏",
				},
			},
		})

		-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
		vim.keymap.set({ "n", "v" }, "<leader>de", dapui.eval, { desc = "Debug: Eval" })
		vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Dap UI" })

		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close

		-- Install golang specific config
		require("dap-go").setup({})

		-- Install python specific config
		local python_path = vim.fn.has("mac") == 1
				and "/opt/homebrew/anaconda3/bin/python"
			or (vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python3")
		require("dap-python").setup(python_path)

		dap.configurations.python = {
			{
				type = "python",
				request = "launch",
				name = "Launch Current File",
				program = "${file}",
			},
		}

		-- Install typescript specific config
		require("dap-vscode-js").setup({
			--node_path = "node",
			--debugger_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
			debugger_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter",
			debugger_cmd = { "js-debug-adapter" },
			adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
		})

		local exts = {
			"javascript",
			"typescript",
			"javascriptreact",
			"typescriptreact",
			-- using pwa-chrome
			"vue",
			"svelte",
		}

		for _, language in ipairs(exts) do
			dap.configurations[language] = {
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch Current File (pwa-node)",
					cwd = vim.fn.getcwd(),
					args = { "${file}" },
					sourceMaps = true,
					protocol = "inspector",
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch Current File (pwa-node with deno)",
					cwd = vim.fn.getcwd(),
					runtimeArgs = { "run", "--inspect-brk", "--allow-all", "${file}" },
					runtimeExecutable = "deno",
					attachSimplePort = 9229,
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch Test Current File (pwa-node with jest)",
					cwd = vim.fn.getcwd(),
					runtimeArgs = { "${workspaceFolder}/node_modules/.bin/jest" },
					runtimeExecutable = "node",
					args = { "${file}", "--coverage", "false" },
					rootPath = "${workspaceFolder}",
					sourceMaps = true,
					console = "integratedTerminal",
					internalConsoleOptions = "neverOpen",
					skipFiles = { "<node_internals>/**", "node_modules/**" },
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch Test Current File (pwa-node with vitest)",
					cwd = vim.fn.getcwd(),
					program = "${workspaceFolder}/node_modules/vitest/vitest.mjs",
					args = { "--inspect-brk", "--threads", "false", "run", "${file}" },
					autoAttachChildProcesses = true,
					smartStep = true,
					console = "integratedTerminal",
					skipFiles = { "<node_internals>/**", "node_modules/**" },
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch Test Current File (pwa-node with deno)",
					cwd = vim.fn.getcwd(),
					runtimeArgs = { "test", "--inspect-brk", "--allow-all", "${file}" },
					runtimeExecutable = "deno",
					attachSimplePort = 9229,
				},
				{
					type = "pwa-chrome",
					request = "attach",
					name = "Attach Program (pwa-chrome = { port: 9222 })",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					port = 9222,
					webRoot = "${workspaceFolder}",
				},
				{
					type = "pwa-node",
					request = "attach",
					name = "Attach Program (pwa-node)",
					cwd = "${workspaceFolder}",
					processId = require("dap.utils").pick_process,
					skipFiles = { "<node_internals>/**" },
					--args = { "${port}" },
					port = 9229,
				},
			}
		end
	end,
}
