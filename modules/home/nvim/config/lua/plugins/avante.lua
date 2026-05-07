-- https://github.com/yetone/avante.nvim
return {
	"yetone/avante.nvim",
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- ⚠️ must add this setting! ! !
	build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
		or "make",
	event = "VeryLazy",
	version = false, -- set this if you want to always pull the latest change
	---@module 'avante'
	---@type avante.Config
	opts = {
		---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
		---@type Provider
		provider = "claude",
		providers = {
			claude = {
				endpoint = "https://api.anthropic.com",
				model = "claude-sonnet-4-20250514",
				timeout = 30000, -- Timeout in milliseconds
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
			openai = {
				endpoint = "https://api.openai.com/v1",
				model = "gpt-4o",
				extra_request_body = {
					temperature = 0,
					max_tokens = 32768,
				},
				--reasoning_effort = "medium"
			},
			copilot = {
				endpoint = "https://api.githubcopilot.com",
				--model = "gpt-4o",
				proxy = nil, -- [protocol://]host[:port] Use this proxy
				allow_insecure = false, -- Allow insecure server connections
				extra_request_body = {
					temperature = 0,
					max_tokens = 4096,
				},
			},
			-- groq = { -- define groq provider
			--     __inherited_from = 'openai',
			--     api_key_name = 'GROQ_API_KEY',
			--     endpoint = 'https://api.groq.com/openai/v1/',
			--     model = 'llama-3.3-70b-versatile',
			--     max_completion_tokens = 32768, -- remember to increase this value, otherwise it will stop generating halfway
			-- },
			--		},
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		--- The below dependencies are optional,
		--"echasnovski/mini.pick", -- for file_selector provider mini.pick
		--"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
		"ibhagwan/fzf-lua", -- for file_selector provider fzf
		"stevearc/dressing.nvim", -- for input provider dressing
		"folke/snacks.nvim", -- for input provider snacks
		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
		"zbirenbaum/copilot.lua", -- for providers='copilot'
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				-- recommended settings
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
					-- required for Windows users
					use_absolute_path = true,
				},
			},
		},
		{
			-- Make sure to set this up properly if you have lazy=true
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
