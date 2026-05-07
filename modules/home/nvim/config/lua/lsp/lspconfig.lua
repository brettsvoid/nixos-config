return { -- lspconfig
	{
		"neovim/nvim-lspconfig",
		--enabled = false,
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			{ "mason-org/mason-lspconfig.nvim" },
			"WhoIsSethDaniel/mason-tool-installer.nvim",

			"b0o/schemastore.nvim",

			-- Useful status updates for LSP.
			-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
			{ "j-hui/fidget.nvim", opts = {} },

			"saghen/blink.cmp",
		},
		opts = function()
			---@class PluginLspOpts
			local ret = {}
			return ret
		end,
		---@param opts PluginLspOpts
		config = function(_, opts)
			-- Cache required modules
			local lspconfig = require("lspconfig")
			local schemastore = require("schemastore")
			-- Define LSP capabilities
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			local border = "rounded"

			-- Add hover and signature help popup windows
			local handlers = {
				-- ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover),
				-- ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
			}

			-- Enable the following language servers
			-- Additional override configuration for the following tables. Available keys are:
			-- - cmd (table): Override the default command used to start the server
			-- - filetypes (table): Override the default list of associated filetypes for the server
			-- - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
			-- - settings (table): Override the default settings passed when initializing the server.
			--       For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
			local servers = {
				biome = {},
				pyright = {
					on_attach = function(client)
						-- Using different formatter (ruff_format)
						client.server_capabilities.documentFormattingProvider = false
						client.server_capabilities.documentRangeFormattingProvider = false
					end,
					settings = {
						python = {
							analysis = {
								autoSearchPaths = true,
								diagnosticMode = "workspace", -- Options: openFilesOnly, workspace
								typeCheckingMode = "strict", -- Options: off, basic, strict
								useLibraryCodeForTypes = true,
							},
						},
					},
				},
				glsl_analyzer = {},
				-- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
				--
				-- Some languages (like typescript) have entire language plugins that can be useful:
				--    https://github.com/pmizio/typescript-tools.nvim
				--
				-- But for many setups, the LSP (`ts_ls`) will work just fine
				-- ts_ls = {
				-- 	filetypes = {
				-- 		"javascript",
				-- 		"javascriptreact",
				-- 		"javascript.jsx",
				-- 		"typescript",
				-- 		"typescriptreact",
				-- 		"typescript.tsx",
				-- 	},
				-- },

				-- Lua Language Server with custom settings
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							diagnostics = {
								globals = { "vim", "hs" },
							},
							workspace = {
								library = {
									vim.fn.expand("$VIMRUNTIME/lua"),
									vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
									"/Applications/Hammerspoon.app/Contents/Resources/extensions/hs/",
									"/Users/brett/.hammerspoon/Spoons/EmmyLua.spoon/annotations",
								},
							},
						},
					},
				},

				html = {},
				cssls = {},

				emmet_ls = {
					filetypes = {
						"html",
						"typescriptreact",
						"javascriptreact",
						"css",
						"sass",
						"scss",
						"less",
						"svelte",
					},
				},

				gopls = {
					filetypes = { "go", "gomod", "gowork", "gotmpl" },
					root_dir = require("lspconfig/util").root_pattern("go.work", "go.mod", ".git"),
					settings = {
						gopls = {
							completeUnimported = true,
							usePlaceholders = true,
							analyses = {
								unusedparams = true,
							},
						},
					},
				},

				terraformls = {
					filetypes = { "terraform" },
				},

				dockerls = {
					filetypes = { "Dockerfile", "dockerfile" },
				},

				jsonls = {
					settings = {
						json = {
							schemas = schemastore.json.schemas(),
							validate = { enable = true },
						},
					},
				},
				yamlls = {
					settings = {
						yaml = {
							schemaStore = {
								enable = false,
								url = "",
							},
							-- Rather specify them at the top of the yaml file if possible like:
							-- # yaml-language-server: $schema=../relative/path/to/schema
							-- schemas = schemastore.yaml.schemas({
							-- 	extra = {
							-- 		{
							-- 			name = "site-builder-global-schema.json",
							-- 			description = "Site build global schema",
							-- 			url = "/Users/brett/work/projects/site-builder/site-builder-global-schema.json",
							-- 			fileMatch = "{tyto,site-builder}/**/global.{yml,yaml}",
							-- 		},
							-- 		{
							-- 			name = "site-builder-page-schema.json",
							-- 			description = "Site builder page schema",
							-- 			url = "/Users/brett/work/projects/site-builder/site-builder-page-schema.json",
							-- 			fileMatch = "{tyto,site-builder}/**/*.{yml,yaml}",
							-- 		},
							-- 	},
							-- }),
						},
					},
				},
			}

			-- Add these filestypes manually. Seems to fix terraform processing when creating a new file.
			vim.filetype.add({
				extension = {
					tf = "terraform",
					tfvars = "terraform",
				},
			})

			--  This function gets run when an LSP attaches to a particular buffer.
			--    That is to say, every time a new file is opened that is associated with
			--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
			--    function will be executed to configure the current buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConf", { clear = true }),
				callback = function(event)
					local buffer = event.buf
					local opts = { buffer = buffer, silent = true, noremap = true }
					local client = vim.lsp.get_client_by_id(event.data.client_id)

					-- Buffer-local Keybindings
					-- Formatting is done by conform, no need to define vim.lsp.buf.format() here
					-- stylua: ignore start
					local buf_keymaps = {
						-- Execute a code action, usually your cursor needs to be on top of an error
						-- or a suggestion from your LSP for this to activate.
						{ "n", "gra",        "<cmd>lua vim.lsp.buf.code_action()<CR>",                "[C]odeAction" },
						{ "n", "<leader>q",  "<cmd>lua vim.diagnostic.setloclist()<CR>",              "Open diagnostics list" },
						-- Opens a popup that displays documentation about the word under your cursor
						--  See `:help K` for why this keymap.
						{ "n", "K",          "<cmd>lua vim.lsp.buf.hover()<CR>",                      "Hover Documentation" },
						{ "n", "]d",         "<cmd>lua vim.diagnostic.goto_next()<CR>",               "Go to next diagnostic" },
						{ "n", "[d",         "<cmd>lua vim.diagnostic.goto_prev()<CR>",               "Go to previous diagnostic" },
						-- Rename the variable under your cursor.
						--  Most Language Servers support renaming across files, etc.
						{ "n", "grn",        "<cmd>lua vim.lsp.buf.rename()<CR>",                     "[R]e[n]ame" },
						-- WARN: This is not Goto Definition, this is Goto Declaration.
						--  For example, in C this would take you to the header.
						{ "n", "gD",         "<cmd>lua vim.lsp.buf.declaration()<CR>",                "[G]oto [D]eclaration" },
						{ "n", "gcI",        "<cmd>lua vim.lsp.buf.incoming_calls()<CR>",             "Goto IncomingCalls" },
						{ "n", "gcO",        "<cmd>lua vim.lsp.buf.outgoing_calls()<CR>",             "Goto OutgoingCalls" },
						-- Jump to the definition of the word under your cursor.
						--  This is where a variable was first declared, or where a function is defined, etc.
						--  To jump back, press <C-t>.
						{ "n", "gd",         "<cmd>lua vim.lsp.buf.definition()<CR>",                 "[G]oto [D]efinition" },
						-- Jump to the implementation of the word under your cursor.
						--  Useful when your language has ways of declaring types without an actual implementation.
						{ "n", "gri",        "<cmd>lua vim.lsp.buf.implementation()<CR>",             "[G]oto [I]mplementation" },
						{ "n", "<C-W>d",     "<cmd>lua vim.diagnostic.open_float()<CR>",              "Open floating diagnostic message" },
						-- Jump to the type of the word under your cursor.
						--  Useful when you're not sure what type a variable is and you want to see
						--  the definition of its *type*, not where it was *defined*.
						{ "n", "<leader>D",  "<cmd>lua vim.lsp.buf.type_definition()<CR>",     "Goto Type [D]efinition" },
						-- Find references for the word under your cursor.
						{ "n", "grr",        "<cmd>lua vim.lsp.buf.references()<CR>",                 "[G]oto [R]eferences" },
						-- Show the signature of the function under your cursor
						{ "n", "<C-s>",      "<cmd>lua vim.lsp.buf.signature_help()<CR>",             "[S]ignature Help" },
						-- Fuzzy find all the symbols in your current document.
						--  Symbols are things like variables, functions, types, etc.
						{ "n", "gO",         "<cmd>lua vim.lsp.buf.document_symbols()<CR>",           "Document Symbols" },
						-- Fuzzy find all the symbols in your current workspace.
						--  Similar to document symbols, except searches over your entire project.
						{ "n", "<leader>sW", "<cmd>lua vim.lsp.buf.dynamic_workspace_symbols()<CR>",  "[W]orkspace [S]ymbols" },

						{ "n", "<leader>gl", "<cmd>lua vim.diagnostic.open_float()<CR>",  "Show [l]ine diagnostics" },
					}
					-- stylua: ignore end

					-- The following autocommand is used to enable inlay hints in your
					-- code, if the language server you are using supports them
					--
					-- This may be unwanted, since they displace some of your code
					if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
						table.insert(buf_keymaps, {
							"n",
							"<leader>th",
							function()
								vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({}))
							end,
							"[T]oggle Inlay [H]ints",
						})
					end

					for _, map in ipairs(buf_keymaps) do
						local modes = type(map[1]) == "table" and map[1] or { map[1] }
						---@diagnostic disable-next-line: param-type-mismatch
						for _, mode in ipairs(modes) do
							vim.keymap.set(mode, map[2], map[3], vim.tbl_extend("force", opts, { desc = map[4] }))
						end
					end

					-- Diagnostic Virtual Text for Current Line
					local ns = vim.api.nvim_create_namespace("CurlineDiag")
					vim.opt.updatetime = 100

					-- The following two autocommands are used to highlight references of the
					-- word under your cursor when your cursor rests there for a little while.
					--    See `:help CursorHold` for information about when this is executed
					--
					-- When you move your cursor, the highlights will be cleared (the second autocommand).
					if client and client.server_capabilities.documentHighlightProvider then
						local highlight_augroup = vim.api.nvim_create_augroup("UserLspHighlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = buffer,
							group = highlight_augroup,
							--callback = vim.lsp.buf.document_highlight,
							callback = function()
								pcall(vim.api.nvim_buf_clear_namespace, buffer, ns, 0, -1)
								local cursor = vim.api.nvim_win_get_cursor(0)
								local current_line = cursor[1] - 1 -- Zero-based index
								local diagnostics = vim.diagnostic.get(buffer, { lnum = current_line })
								if not diagnostics or #diagnostics == 0 then
									return
								end

								local virt_texts = {}
								for _, diag in ipairs(diagnostics) do
									local severity = vim.diagnostic.severity[diag.severity] or "Error"
									table.insert(virt_texts, { diag.message, "Diagnostic" .. severity })
								end

								vim.api.nvim_buf_set_extmark(buffer, ns, current_line, 0, {
									virt_text = virt_texts,
									hl_mode = "combine",
								})
							end,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = buffer,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("UserLspDetach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "UserLspHighlight", buffer = event2.buf })
							end,
						})
					end
				end,
			})

			-- Global Diagnostic Configuration
			vim.diagnostic.config({
				virtual_text = false,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			require("mason-lspconfig").setup({
				ensure_installed = {}, -- explicitly set to an empty table, this is handled by mason-tool-installer
				automatic_enable = true,
				automatic_installation = false,
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						-- This handles overriding only values explicitly passed
						-- by the server configuration above. Useful when disabling
						-- certain features of an LSP (for example, turning off formatting for ts_ls)
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						server.handlers = handlers
						lspconfig[server_name].setup(server)
					end,
				},
			})

			-- Add border to the diagnostic popup window
			vim.diagnostic.config({
				virtual_text = {
					--prefix = "■ ", -- Could be '●', '▎', 'x', '■', , 
				},
				float = { border = border },
			})

			-- Ensure the servers and tools above are installed
			--  To check the current status of installed tools and/or manually install
			--  other tools, you can run
			--    :Mason
			--
			--  You can press `g?` for help in this menu.
			require("mason").setup()

			-- You can add other tools here that you want Mason to install
			-- for you, so that they are available from within Neovim.
			-- local ensure_installed = vim.tbl_keys(servers or {})
			-- vim.list_extend(ensure_installed, {
			-- 	"stylua", -- lua formatter
			-- 	"selene", -- lua linter
			--
			-- 	"black", -- python formatter
			-- 	"pylint", -- python linter
			--
			-- 	"prettierd", -- prettier formatter
			-- 	"prettier", -- prettier formatter
			-- 	"eslint", -- js linter
			--
			-- 	"dockerls", -- dockerfile language server
			--
			-- 	"gopls", -- go language server
			-- 	"gofumpt", -- go formatter (used by none-ls)
			-- 	"goimports-reviser", -- go imports sorter (used by none-ls)
			-- 	"golines", -- go line shortener if longer than 80 characters (used by none-ls)
			-- })
			-- require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			local on_attach = function(client, bufnr)
				local keymap = vim.keymap -- for conciseness
				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

				-- opts.desc = "Show line diagnostics"
				-- vim.keymap.set("n", "<leader>gl", vim.diagnostic.open_float, opts) -- show diagnostics for line

				--     opts.desc = "Go to previous diagnostic"
				--     keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer

				--     opts.desc = "Go to next diagnostic"
				--     keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer

				--     opts.desc = "Restart LSP"
				--     keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
			end

			-- Change the Diagnostic symbols in the sign column (gutter)
			-- (not in youtube nvim video)
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end
		end,
	},

	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		--keys = { { '<leader>cm', '<cmd>Mason<cr>', desc = '[M]ason' } },
		build = ":MasonUpdate",
		opts = {
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
				check_outdated_packages_on_open = true,
				border = "rounded",
				width = 0.9,
				height = 0.9,
			},
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(_, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			local ensure_installed = opts.ensure_installed or {}

			mr:on("package:install:success", function()
				vim.defer_fn(function()
					-- trigger FileType event to possibly load this newly installed LSP server
					require("lazy.core.handler.event").trigger({
						event = "FileType",
						buf = vim.api.nvim_get_current_buf(),
					})
				end, 100)
			end)

			mr.refresh(function()
				for _, tool in ipairs(ensure_installed) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						p:install()
					end
				end
			end)
		end,
	},
}
