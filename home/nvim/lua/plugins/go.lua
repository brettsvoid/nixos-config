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
	build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
	opts = {
		-- Format on save
		gofmt = "gofumpt", -- gofmt cmd
		--goimports = "gopls", -- goimports cmd (previously goimport)
		tag_transform = false, -- tag_transfer  check gomodifytags for details
		test_template = "", -- default to testify if not set; g:go_nvim_tests_template  check gotests for details
		test_template_dir = "", -- default to nil if not set; g:go_nvim_tests_template_dir  check gotests for details
		comment_placeholder = "", -- comment_placeholder your cool placeholder e.g. ﳑ
		icons = { breakpoint = "🧘", currentpos = "🏃" },
		verbose = false, -- output loginf in messages
		lsp_cfg = true, -- true: use non-default gopls setup specified in go/lsp.lua
		-- false: do nothing
		-- if lsp_cfg is a table, merge table with with non-default gopls setup in go/lsp.lua, e.g.
		--   lsp_cfg = {settings={gopls={matcher='CaseInsensitive', ['local'] = 'your_local_module_path', gofumpt = true }}}
		lsp_gofumpt = true, -- true: set default gofmt in gopls format to gofumpt
		lsp_on_attach = nil, -- nil: use on_attach function defined in go/lsp.lua,
		--      when lsp_cfg is true
		-- if lsp_on_attach is a function: use this function as on_attach function for gopls
		lsp_keymaps = true, -- set to false to disable gopls/lsp keymap
		lsp_codelens = true, -- set to false to disable codelens, true by default, you can use a function
		-- function(bufnr)
		--    vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>F", "<cmd>lua vim.lsp.buf.formatting()<CR>", {noremap=true, silent=true})
		-- end
		-- to setup a table of codelens
		diagnostic = { -- set diagnostic to false to disable vim.diagnostic setup
			hdlr = false, -- hook lsp diag handler and send diag to quickfix
			underline = true,
			virtual_text = { space = 0, prefix = "" },
			signs = true,
		},
		-- Format on save
		formatter_on_save = true,
		-- Run `go test` on save
		test_runner = "go", -- richgo, go test, richgo, dlv, ginkgo
		run_in_floaterm = true, -- set to true to run in float window.
		-- float term recommended if you use richgo/ginkgo with terminal color
	},
	config = function(_, opts)
		require("go").setup(opts)

		-- Run gofmt + goimport on save
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
