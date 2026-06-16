return { -- lspconfig
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"b0o/schemastore.nvim",

			{ "j-hui/fidget.nvim", opts = {} },

			"saghen/blink.cmp",
		},
		config = function()
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			vim.lsp.config("*", { capabilities = capabilities })

			-- Enable the servers configured under nvim/lsp/*.lua. Every binary
			-- is provided declaratively by Nix (modules/home/nvim/default.nix),
			-- so there is no Mason install step — this is the single source of
			-- truth for which language servers run.
			vim.lsp.enable({
				"lua_ls",
				"nixd", -- evaluation-driven completion (options, packages)
				"nil_ls", -- static lints (unused bindings, dead code, deprecations)
				"gopls",
				"pyright",
				"jsonls",
				"yamlls",
				"emmet_ls",
				"terraformls",
				"dockerls",
				"biome",
				"html",
				"cssls",
				"tailwindcss",
				"glsl_analyzer",
				"hls",
			})

			vim.filetype.add({
				extension = {
					tf = "terraform",
					tfvars = "terraform",
				},
			})

			vim.opt.updatetime = 100

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConf", { clear = true }),
				callback = function(event)
					local buffer = event.buf
					local opts = { buffer = buffer, silent = true, noremap = true }
					local client = vim.lsp.get_client_by_id(event.data.client_id)

					-- stylua: ignore start
					local buf_keymaps = {
						{ "n", "<leader>q",  "<cmd>lua vim.diagnostic.setloclist()<CR>",              "Open diagnostics list" },
						{ "n", "gD",         "<cmd>lua vim.lsp.buf.declaration()<CR>",                "[G]oto [D]eclaration" },
						{ "n", "gcI",        "<cmd>lua vim.lsp.buf.incoming_calls()<CR>",             "Goto IncomingCalls" },
						{ "n", "gcO",        "<cmd>lua vim.lsp.buf.outgoing_calls()<CR>",             "Goto OutgoingCalls" },
						{ "n", "gd",         "<cmd>lua vim.lsp.buf.definition()<CR>",                 "[G]oto [D]efinition" },
						{ "n", "<leader>D",  "<cmd>lua vim.lsp.buf.type_definition()<CR>",            "Goto Type [D]efinition" },
						{ "n", "<leader>sW", "<cmd>lua vim.lsp.buf.dynamic_workspace_symbols()<CR>",  "[W]orkspace [S]ymbols" },
					}
					-- stylua: ignore end

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

					-- Document highlighting
					if client and client.server_capabilities.documentHighlightProvider then
						local highlight_augroup = vim.api.nvim_create_augroup("UserLspHighlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = buffer,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
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

			vim.diagnostic.config({
				virtual_lines = { current_line = true },
				virtual_text = false,
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.HINT] = "󰠠 ",
						[vim.diagnostic.severity.INFO] = " ",
					},
				},
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = { border = "rounded" },
			})

		end,
	},

	-- Mason is retained solely for nvim-dap's debug adapters (see debug.lua);
	-- it no longer manages language servers, formatters, or linters — Nix does.
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
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
	},
}
