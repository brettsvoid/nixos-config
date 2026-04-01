return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = function()
		local harpoon = require("harpoon")
		return {
			{
				"<leader>he",
				function()
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "View all project marks",
			},
			{
				"<leader>ha",
				function()
					harpoon:list():add()
				end,
				desc = "Mark a file",
			},
			{
				"<leader>hn",
				function()
					harpoon:list():next()
				end,
				desc = "Navigate to next mark",
			},
			{
				"<leader>hp",
				function()
					harpoon:list():prev()
				end,
				desc = "Navigate to previous mark",
			},
			{
				"<leader>h1",
				function()
					harpoon:list():select(1)
				end,
				desc = "Navigate to mark 1",
			},
			{
				"<leader>h2",
				function()
					harpoon:list():select(2)
				end,
				desc = "Navigate to mark 2",
			},
			{
				"<leader>h3",
				function()
					harpoon:list():select(3)
				end,
				desc = "Navigate to mark 3",
			},
			{
				"<leader>h4",
				function()
					harpoon:list():select(4)
				end,
				desc = "Navigate to mark 4",
			},
			{
				"<leader>h5",
				function()
					harpoon:list():select(5)
				end,
				desc = "Navigate to mark 5",
			},
		}
	end,
}
