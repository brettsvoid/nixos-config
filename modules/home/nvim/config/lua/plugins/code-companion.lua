-- https://github.com/olimorris/codecompanion.nvim
return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		strategies = {
			chat = { adapter = "anthropic" },
			inline = { adapter = "anthropic" },
		},
		adapters = {
			http = {
				openai = function()
					return require("codecompanion.adapters").extend("anthropic", {
						env = {
							api_key = "cmd:bws secret get fef4e9b2-ab71-4508-a774-b2520144753c | jq -r '.value'",
						},
					})
				end,
			},
		},
	},
}
