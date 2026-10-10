-- Autoformat

-- Whether any of config_files exists upwards from the buffer's directory (to $HOME).
local function has_config(bufnr, config_files)
	local found = vim.fs.find(config_files, {
		upward = true,
		path = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
		stop = vim.env.HOME,
	})
	return #found > 0
end

-- Biome or Prettier, whichever the project configures.
local function get_web_formatter(bufnr)
	-- Biome wins if both are configured
	if has_config(bufnr, { "biome.json", "biome.jsonc" }) then
		return { "biome" }
	end
	if
		has_config(bufnr, {
			".prettierrc",
			".prettierrc.json",
			".prettierrc.yaml",
			".prettierrc.yml",
			".prettierrc.js",
			".prettierrc.cjs",
			".prettierrc.mjs",
			"prettier.config.js",
			"prettier.config.cjs",
			"prettier.config.mjs",
		})
	then
		return { "prettier" }
	end
	-- Neither: LSP fallback
	return {}
end

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true })
			end,
			mode = { "n", "v" },
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		default_format_opts = {
			lsp_format = "fallback",
		},
		formatters_by_ft = {
			bash = { "shfmt" },
			lua = { "stylua" },
			sh = { "shfmt" },
			sql = { "sql_formatter" },
			toml = { "taplo" },
			zsh = { "shfmt" },
			rust = { "rustfmt" },
			python = { "isort", "black" },
			-- Terraform/terragrunt
			hcl = { "terragrunt_hclfmt" },
			terraform = { "terraform_fmt" },

			-- Biome, Prettier or LSP, per project config (see get_web_formatter).
			javascript = get_web_formatter,
			javascriptreact = get_web_formatter,
			typescript = get_web_formatter,
			typescriptreact = get_web_formatter,
			json = get_web_formatter,
			jsonc = get_web_formatter,
			-- Always Prettier. Biome can't format these, CSS aside.
			css = { "prettier" },
			html = { "prettier" },
			markdown = { "prettier" },
			scss = { "prettier" },
			yaml = { "prettier" },

			go = { "gofumpt", "goimports_reviser", "golines" },

			-- Match formatter.nix and the git-hooks pre-commit.
			nix = { "nixfmt" },

			["*"] = { "injected" },
		},
		format_on_save = function(bufnr)
			-- No format-on-save for languages without one standard style.
			local ignore_filetypes = { "c", "cpp" }
			if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
				return
			end

			-- Nor under node_modules
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			if bufname:match("/node_modules/") then
				return
			end

			return { timeout_ms = 5000 }
		end,
		formatters = {
			shfmt = {
				prepend_args = { "-i", "2" }, -- indent with two spaces
			},
			sql_formatter = {
				prepend_args = { "-c", vim.fn.expand("~/.config/sql_formatter.json") },
			},
		},
		notify_on_error = true,
	},
	init = function()
		-- gq formats through conform
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
