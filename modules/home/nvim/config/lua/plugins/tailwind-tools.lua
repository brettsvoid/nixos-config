-- https://github.com/luckasRanarison/tailwind-tools.nvim
return {
	{
		"luckasRanarison/tailwind-tools.nvim",
		name = "tailwind-tools",
		build = ":UpdateRemotePlugins",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-telescope/telescope.nvim", -- optional
			"neovim/nvim-lspconfig", -- optional
		},
		---@type TailwindTools.Option
		opts = {
			server = {
				override = false, -- Don't use deprecated lspconfig setup; tailwindcss is configured via lsp/tailwindcss.lua
			},
			extension = {
				queries = { "typescriptreact" },
				patterns = {
					javascript = {
						"imageClassName=[\"']([^\"']+)[\"']",
					},
					typescript = {
						"imageclassname=[\"']([^\"']+)[\"']",
					},
					typescriptreact = {
						"imageclassname=[\"']([^\"']+)[\"']",
					},
				},
			},
		},
	},
}
