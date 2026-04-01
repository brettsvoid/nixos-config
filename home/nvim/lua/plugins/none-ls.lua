return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvimtools/none-ls-extras.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	opts = function(_, opts)
		local builtins = require("null-ls").builtins
		opts.sources = vim.list_extend(opts.sources or {}, {
			sources = {
				require("none-ls.code_actions.eslint"),
				require("none-ls.diagnostics.eslint"),
			},
		})

		-- Go options
		opts.sources = vim.list_extend(opts.sources or {}, {
			sources = {
				builtins.formatting.gofumpt,
				builtins.formatting.goimports_reviser,
				builtins.formatting.golines,
			},
		})
	end,
}
