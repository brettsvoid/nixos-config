return {
	-- https://github.com/Saghen/blink.cmp
	{
		"saghen/blink.cmp",
		--enabled = false,
		version = "*",
		build = "cargo build --release",
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

			--cmdline =  function()
			-- 	local type = vim.fn.getcmdtype()
			-- 	-- Search forward and backward
			-- 	if type == "/" or type == "?" then
			-- 		return { "buffer" }
			-- 	end
			-- 	-- Commands
			-- 	if type == ":" then
			-- 		return { "cmdline" }
			-- 	end
			-- 	return {}
			-- end,
			--},

			completion = {
				accept = { auto_brackets = { enabled = true } },

				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					treesitter_highlighting = true,
					window = { border = "rounded" },
				},

				-- list = {
				-- 	selection = {
				-- 		preselect = function(ctx)
				-- 			return ctx.mode ~= "cmdline" and not require("blink.cmp").snippet_active({ direction = 1 })
				-- 		end,
				-- 		auto_insert = function(ctx)
				-- 			return ctx.mode ~= "cmdline"
				-- 		end,
				-- 	},
				-- },

				menu = {
					draw = {
						treesitter = { "lsp" },
					},
				},
				-- menu = {
				-- 	border = "rounded",
				-- 	cmdline_position = function()
				-- 		if vim.g.ui_cmdline_pos ~= nil then
				-- 			local pos = vim.g.ui_cmdline_pos -- (1, 0)-indexed
				-- 			return { pos[1] - 1, pos[2] }
				-- 		end
				-- 		local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
				-- 		return { vim.o.lines - height, 0 }
				-- 	end,
				-- 	draw = {
				-- 		columns = {
				-- 			{ "kind_icon", "label", gap = 1 },
				-- 			{ "kind" },
				-- 		},
				-- 		components = {
				-- 			kind_icon = {
				-- 				text = function(item)
				-- 					local kind = require("lspkind").symbol_map[item.kind] or ""
				-- 					return kind .. " "
				-- 				end,
				-- 				highlight = "CmpItemKind",
				-- 			},
				-- 			label = {
				-- 				text = function(item)
				-- 					return item.label
				-- 				end,
				-- 				highlight = "CmpItemAbbr",
				-- 			},
				-- 			kind = {
				-- 				text = function(item)
				-- 					return item.kind
				-- 				end,
				-- 				highlight = "CmpItemKind",
				-- 			},
				-- 		},
				-- 	},
				-- },
			},

			keymap = {
				preset = "default",

				-- ["<C-space>"] = {
				-- 	function(cmp)
				-- 		cmp.show({ providers = { "lsp", "path", "snippets", "buffer", "dadbod" } })
				-- 	end,
				-- },
			},

			-- Experimental signature help support
			signature = {
				enabled = true,
				window = { border = "rounded" },
			},

			sources = {
				default = { "lsp", "path", "snippets", "buffer", "dadbod" },
				providers = {
					-- lsp = {
					-- 	min_keyword_length = 1, -- Number of characters to trigger provider
					-- 	score_offset = 0, -- Boost/penalize the score of the items
					-- },
					-- path = {
					-- 	min_keyword_length = 0,
					-- 	score_offset = -5, -- Boost/penalize the score of the items
					-- },
					-- snippets = {
					-- 	min_keyword_length = 2,
					-- 	score_offset = -10, -- Boost/penalize the score of the items
					-- },
					-- buffer = {
					-- 	min_keyword_length = 5,
					-- 	max_items = 5,
					-- 	score_offset = -15, -- Boost/penalize the score of the items
					-- },
					dadbod = {
						name = "Dadbod",
						module = "vim_dadbod_completion.blink",
					},
				},
			},
		},
	},
}
