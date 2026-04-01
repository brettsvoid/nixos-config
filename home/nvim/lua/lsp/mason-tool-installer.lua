-- https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
return {
	"WhoIsSethDaniel/mason-tool-installer.nvim",
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
	},
	opts = {
		ensure_installed = {
			"dockerls", -- dockerfile language server

			"gopls", -- go language server
			"gofumpt", -- go formatter (used by none-ls)
			"goimports-reviser", -- go imports sorter (used by none-ls)
			"golines", -- go line shortener if longer than 80 characters (used by none-ls)

			"eslint_d", -- js/ts linter
			"prettierd", -- js/ts/json formatter

			"stylua", -- lua formatter
			"selene", -- lua linter

			"black", -- python formatter
			"pylint", -- python linter
			"pyright", -- python static type checker

			-- other
			"bashls",
			"html",
			"jsonlint",
			"jsonls",
			"lua_ls",
			"markdownlint",
			"marksman",
			"shellcheck",
			"shfmt",
			"taplo",
			"yamllint",
			"yamlls",

		},
	},
}
