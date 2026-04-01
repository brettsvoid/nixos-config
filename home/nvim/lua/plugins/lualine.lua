-- Fancier statusline
return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		--'nvim-tree/nvim-web-devicons',
		"echasnovski/mini.icons",
	},
	opts = {
		options = {
			theme = "catppuccin",
		},
		sections = {
			lualine_c = {
				{ "filename", path = 1 },
			},
		},
	},
}
