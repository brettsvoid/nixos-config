local personal_vault = vim.fn.expand("~") .. "/Documents/Obsidian Vault"
local work_vault = vim.fn.expand("~") .. "/Documents/Work Vault"

-- A Neovim plugin for writing and navigating Obsidian vaults.
-- https://github.com/epwalsh/obsidian.nvim
return {
	"epwalsh/obsidian.nvim",
	version = "*", -- recommended, use latest release instead of latest commit
	lazy = true,
	cmd = {
		"ObsidianNew",
		"ObsidianOpen",
		"ObsidianSearch",
	},
	event = {
		"BufReadPre " .. personal_vault .. "/*.md",
		"BufReadPre " .. work_vault .. "/*.md",
		"BufNewFile " .. personal_vault .. "/*.md",
		"BufNewFile " .. work_vault .. "/*.md",
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"nvim-treesitter",
	},
	opts = {
		new_notes_location = ".notes_subdir",
		notes_subdir = ".inbox",
		ui = { enable = false },
		workspaces = {
			{
				name = "personal",
				path = "~/Documents/Obsidian Vault",
			},
			{
				name = "work",
				path = "~/Documents/Work Vault",
			},
		},
	},
}
