-- https://github.com/folke/lazydev.nvim
return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				"$HOME/.config/nvim",
				-- Load luvit types when the `vim.uv` word is found
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				--'$HOME/.config/wezterm',
				--{ path = 'wezterm-types', mods = { 'wezterm' } },
			},
		},
	},
	{ -- optional blink completion source for require statements and module annotations
		"saghen/blink.cmp",
		opts = {
			sources = {
				default = { "lazydev", "lsp", "path", "snippets", "buffer" },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						-- make lazydev completions top priority (see `:h blink.cmp`)
						score_offset = 100,
					},
				},
			},
		},
	},
}
