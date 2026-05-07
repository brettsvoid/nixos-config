-- "gc" to comment visual regions/lines
-- :help comment-nvim
return {
	"numToStr/Comment.nvim",
	dependencies = {
		"JoosepAlviste/nvim-ts-context-commentstring", -- comment jsx/tsx
		"nvim-treesitter/nvim-treesitter",
	},
}
