return {
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
		"TmuxNavigatePrevious",
	},
	keys = {
		{ "<A-Left>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux/vim)" },
		{ "<A-Down>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux/vim)" },
		{ "<A-Up>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux/vim)" },
		{ "<A-Right>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/vim)" },
	},
}
