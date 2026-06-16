-- https://github.com/ibhagwan/fzf-lua
return {
	"ibhagwan/fzf-lua",
	dependencies = {
		"echasnovski/mini.icons",
		"MeanderingProgrammer/render-markdown.nvim",
	},
	--cmd = { 'FzfLua' },
	opts = {
		"default", -- fzf profile
		async = true, -- Enable async for fzf
		defaults = {
			file_icons = true,
			git_icons = true,
			color_icons = true,
		},
		winopts = {
			height = 0.8,
			preview = {
				layout = "vertical",
				vertical = "up:70%",
			},
			border = "rounded",
			fullscreen = false,
			on_create = function()
				vim.keymap.set("t", "<C-r>", [['<C-\><C-N>"'.nr2char(getchar()).'pi']], { expr = true, buffer = true })
			end,
		},
		keymap = {
			builtin = {
				["<C-u>"] = "preview-page-up",
				["<C-d>"] = "preview-page-down",
				["<C-\\>"] = "toggle-preview",
			},
			fzf = {
				["ctrl-q"] = "select-all+accept",
			},
		},
		fzf_opts = {
			["--layout"] = "reverse-list",
			["--marker"] = "+",
		},
		previewers = {
			builtin = {
				syntax = true, -- preview syntax highlight?
				syntax_limit_l = 1024, -- syntax limit (lines), 0=nolimit
				syntax_limit_b = 1024 * 500, -- syntax limit (bytes), 0=nolimit
				limit_b = 1024 * 1024 * 5, -- preview limit (bytes), 0=nolimit
				extensions = {
					["jpg"] = { "viu", "-b" },
					["jpeg"] = { "viu", "-b" },
					["svg"] = { "viu", "-b" },
					["png"] = { "viu", "-b" },
				},
			},
		},
		oldfiles = {
			include_current_session = true,
		},
		grep = {
			rg_glob = true,
			glob_flag = "--iglob",
			glob_separator = "%s%-%-",
		},
	},
	keys = {
		{ "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Commits Project" },
		{ "<leader>gC", "<cmd>FzfLua git_bcommits<cr>", desc = "Commits Buffer" },
		{ "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Status" },
		{ "<leader>gB", "<cmd>FzfLua git_blame<cr>", desc = "Blame" },

		{ "<leader>sc", "<cmd>FzfLua commands<cr>", desc = "[S]earch [C]ommands" },
		{ "<leader>sh", "<cmd>FzfLua helptags<cr>", desc = "[S]earch [H]elp" },
		{ "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "[S]earch [K]eymaps" },
		{ "<leader>sf", "<cmd>FzfLua files<cr>", desc = "[S]earch [F]iles" },
		{ "<leader>ss", "<cmd>FzfLua builtin<cr>", desc = "[S]earch [S]elect" },
		{ "<leader>sw", "<cmd>FzfLua grep<cr>", desc = "[S]earch current [W]ord" },
		{ "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "[S]earch by [G]rep" },
		{ "<leader>sd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "[S]earch [D]iagnostics" },
		{ "<leader>sr", "<cmd>FzfLua resume<cr>", desc = "[S]earch [R]esume" },
		{ "<leader>s.", "<cmd>FzfLua oldfiles<cr>", desc = '[S]earch Recent Files ("." for repeat)' },
	},
}
