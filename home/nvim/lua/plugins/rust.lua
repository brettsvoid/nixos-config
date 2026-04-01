return {
	"mrcjkb/rustaceanvim",
	dependencies = {},
	version = "^5", -- Recommended
	lazy = false, -- This plugin is already lazy
	ft = "rust",
	keys = {
		-- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
		{
			"<leader>gra",
			function()
				vim.cmd.RustLsp("codeAction") -- supports rust-analyzer's grouping
			end,
			silent = true,
			buffer = vim.api.nvim_get_current_buf,
			mode = { "n" },
			desc = "[C]ode action",
		},
		{
			"<leader>K",
			function()
				vim.cmd.RustLsp({ "hover", "actions" }) -- supports rust-analyzer's grouping
			end,
			silent = true,
			buffer = vim.api.nvim_get_current_buf,
			mode = { "n" },
			desc = "Hover actions",
		},
		{
			"<leader>gld",
			function()
				vim.cmd.RustLsp({ "renderDiagnostic", "current" })
			end,
			silent = true,
			--buffer = vim.api.nvim_get_current_buf,
			mode = { "n" },
			desc = "Show line diagnostics",
		},
		{
			"<leader>J",
			function()
				vim.cmd.RustLsp({ "moveItem", "down" })
			end,
			silent = true,
			buffer = vim.api.nvim_get_current_buf,
			mode = { "v" },
			desc = "Move item down",
		},
		{
			"<leader>K",
			function()
				vim.cmd.RustLsp({ "moveItem", "up" })
			end,
			silent = true,
			buffer = vim.api.nvim_get_current_buf,
			mode = { "v" },
			desc = "Move item up",
		},
	},
	init = function()
		-- Temporary workaround until the next update in Feb 2025
		-- https://github.com/neovim/neovim/issues/30985
		for _, method in ipairs({ "textDocument/diagnostic", "workspace/diagnostic" }) do
			local default_diagnostic_handler = vim.lsp.handlers[method]
			vim.lsp.handlers[method] = function(err, result, context, config)
				if err ~= nil and err.code == -32802 then
					return
				end
				return default_diagnostic_handler(err, result, context, config)
			end
		end
	end,
}
