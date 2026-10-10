return {
	-- https://github.com/Saghen/blink.cmp
	{
		"saghen/blink.cmp",
		--enabled = false,
		version = "*",
		-- No build step: on a release tag blink downloads its prebuilt fuzzy
		-- matcher; only branch=main needs `cargo build`.
		-- Lets other specs (e.g. lazydev.lua) extend these lists.
		opts_extend = {
			"sources.completion.enabled_providers",
			"sources.compat",
			"sources.default",
		},
		dependencies = {
			"rafamadriz/friendly-snippets",
			--"onsails/lspkind.nvim",
		},
		event = "InsertEnter",

		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			appearance = {
				-- Fall back to nvim-cmp's highlight groups for themes without
				-- blink.cmp support (slated for removal upstream)
				use_nvim_cmp_as_default = true,
				-- 'mono' for Nerd Font Mono, 'normal' for Nerd Font (icon spacing)
				nerd_font_variant = "mono",
			},

			completion = {
				accept = { auto_brackets = { enabled = true } },

				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					treesitter_highlighting = true,
					window = { border = "rounded" },
				},

				menu = {
					draw = {
						treesitter = { "lsp" },
					},
				},
			},

			keymap = {
				preset = "default",
			},

			-- Experimental signature help support
			signature = {
				enabled = true,
				window = { border = "rounded" },
			},

			sources = {
				default = { "lsp", "path", "snippets", "buffer", "dadbod" },
				providers = {
					dadbod = {
						name = "Dadbod",
						module = "vim_dadbod_completion.blink",
					},
				},
			},
		},
	},
}
