return {
	"mrcjkb/rustaceanvim",
	dependencies = {},
	version = "^5", -- Recommended
	lazy = false, -- This plugin is already lazy
	ft = "rust",
	keys = {
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
				vim.cmd.RustLsp({ "hover", "actions" })
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
		vim.g.rustaceanvim = {
			server = {
				default_settings = {
					["rust-analyzer"] = {
						cargo = { targetDir = true },
					},
				},
			},
		}

		-- Drop ServerCancelled (-32802) diagnostic errors, per
		-- https://github.com/neovim/neovim/issues/30985. Neovim 0.12 handles these
		-- itself (runtime lsp/diagnostic.lua), so this is a removal candidate.
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
