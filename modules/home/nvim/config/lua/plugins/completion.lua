return {
	-- https://github.com/Saghen/blink.cmp
	{
		"saghen/blink.cmp",
		--enabled = false,
		version = "*",
		-- No build step: pinned to a release tag, so blink downloads the
		-- prebuilt libblink_cmp_fuzzy for that tag on first launch instead of
		-- compiling from source. (cargo build is only needed on branch=main.)
		-- allows extending the providers array elsewhere in your config
		-- without having to redefine it
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
				-- Sets the fallback highlight groups to nvim-cmp's highlight groups
				-- Useful for when your theme doesn't support blink.cmp
				-- will be removed in a future release
				use_nvim_cmp_as_default = true,
				-- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
				-- Adjusts spacing to ensure icons are aligned
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
