-- https://github.com/nvim-pack/nvim-spectre
return {
	"nvim-pack/nvim-spectre",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		default = {
			replace = {
				cmd = "oxi",
			},
		},
	},
}
