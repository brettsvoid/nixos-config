-- https://github.com/stevearc/oil.nvim
---@type LazySpec
return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	dependencies = {
		--'nvim-tree/nvim-web-devicons'
		"echasnovski/mini.icons",
	},
	keys = {
		-- Open parent directory in current window
		{ "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
		-- {
		-- 	"<leader>-",
		-- 	function()
		-- 		require("oil").toggle_float()
		-- 	end,
		-- 	desc = "Open parent directory (floating window)",
		-- },
		{
			"<ESC>",
			function()
				require("oil").close()
			end,
			desc = "Close Oil",
			ft = "oil", -- Only active in Oil buffers
		},
	},
	opts = {
		columns = { "icon" },
		view_options = {
			show_hidden = true,
		},
	},
}
