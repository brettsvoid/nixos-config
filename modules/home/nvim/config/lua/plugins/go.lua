-- https://github.com/ray-x/go.nvim
return {
	"ray-x/go.nvim",
	enabled = false,
	dependencies = { -- optional packages
		"ray-x/guihua.lua",
		"neovim/nvim-lspconfig",
		"nvim-treesitter/nvim-treesitter",
	},
	event = { "CmdlineEnter" },
	ft = { "go", "gomod" },
	build = ':lua require("go.install").update_all_sync()', -- install/update go.nvim's binaries
	opts = {
		gofmt = "gofumpt", -- gofmt cmd
		--goimports = "gopls", -- goimports cmd
		tag_transform = false, -- see gomodifytags
		test_template = "", -- see gotests
		test_template_dir = "", -- see gotests
		comment_placeholder = "",
		icons = { breakpoint = "🧘", currentpos = "🏃" },
		verbose = false,
		lsp_cfg = true, -- use go.nvim's gopls setup (go/lsp.lua); a table is merged into it
		lsp_gofumpt = true, -- gopls formats with gofumpt
		lsp_on_attach = nil, -- nil: go/lsp.lua's on_attach (when lsp_cfg is true)
		lsp_keymaps = true, -- set to false to disable gopls/lsp keymap
		lsp_codelens = true,
		diagnostic = { -- set diagnostic to false to disable vim.diagnostic setup
			hdlr = false, -- hook lsp diag handler and send diag to quickfix
			underline = true,
			virtual_text = { space = 0, prefix = "" },
			signs = true,
		},
		formatter_on_save = true,
		test_runner = "go", -- go, richgo, dlv, ginkgo
		run_in_floaterm = true, -- float window; recommended for richgo/ginkgo colours
	},
	config = function(_, opts)
		require("go").setup(opts)

		-- goimports on save
		local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = "*.go",
			callback = function()
				require("go.format").goimport()
			end,
			group = format_sync_grp,
		})
	end,
}
