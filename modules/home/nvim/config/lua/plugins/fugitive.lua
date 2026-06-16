return {
	"tpope/vim-fugitive",
	keys = {
		{ "<leader>Gf", vim.cmd.Git, desc = "[G]it [F]ugitive" },
		{ "<leader>Gd", vim.cmd.Gvdiffsplit, desc = "[G]it Fugitive [D]iff" },
	},
}
