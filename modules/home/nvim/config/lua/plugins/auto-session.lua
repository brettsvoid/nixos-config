-- https://github.com/rmagatti/auto-session
return {
	"rmagatti/auto-session",
	enabled = false,
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	lazy = false,
	keys = {
		{ "<leader>wl", "<cmd>SessionSearch<CR>", desc = "[W]orkspace [L]ist" },
		{ "<leader>ws", "<cmd>SessionSave<CR>", desc = "[W]orkspace [S]ave" },
		{ "<leader>wa", "<cmd>SessionToggleAutoSave<CR>", desc = "[W]orkspace Toggle [A]utosave" },
		{ "<leader>wr", "<cmd>SessionRestore<CR>", desc = "[W]orkspace [R]estore" },
		{ "<leader>wd", "<cmd>SessionDelete<CR>", desc = "[W]orkspace [D]elete" },
	},
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "/", "~/", "~/projects", "~/work", "~/work/projects" },
	},
}
