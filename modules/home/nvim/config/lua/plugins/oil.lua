-- https://github.com/stevearc/oil.nvim
---@type LazySpec
return {
	"stevearc/oil.nvim",
	dependencies = {
		--'nvim-tree/nvim-web-devicons'
		"echasnovski/mini.icons",
	},
	keys = {
		{ "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
		{
			"<ESC>",
			function()
				require("oil").close()
			end,
			desc = "Close Oil",
			ft = "oil", -- Only active in Oil buffers
		},
	},
	---@module 'oil'
	---@type oil.SetupOpts
	opts = {
		columns = { "icon" },
		view_options = {
			show_hidden = true,
		},
	},
}
