-- https://github.com/3rd/diagram.nvim
return {
	"3rd/diagram.nvim",
	event = "VeryLazy",
	dependencies = {
		{ "3rd/image.nvim" },
	},
	opts = function()
		return {
			integrations = {
				require("diagram.integrations.markdown"),
				require("diagram.integrations.neorg"),
			},
			renderer_options = {
				mermaid = {
					background = nil, -- nil for transparent background
					theme = nil, -- default, forest, dark, neutral
					scale = 1,
				},
				plantuml = {
					charset = "utf-8",
				},
				d2 = {
					theme_id = nil,
					layout = nil,
					sketch = false,
				},
			},
		}
	end,
	keys = {
		{
			"<leader>dh",
			function()
				require("diagram").show_diagram_hover()
			end,
			mode = "n",
			ft = { "markdown", "norg" },
			desc = "Show diagram in new tab",
		},
	},
}
