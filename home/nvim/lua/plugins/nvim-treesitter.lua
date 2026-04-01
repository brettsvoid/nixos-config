-- Highlight, edit, and navigate code
return {
	"nvim-treesitter/nvim-treesitter",
	-- dependencies = { 'nvim-treesitter/playground' },
	build = ":TSUpdate",
	opts = {
		ensure_installed = { "bash", "c", "diff", "html", "lua", "luadoc", "markdown", "vim", "vimdoc" },
		-- Autoinstall languages that are not installed
		auto_install = true,
		highlight = {
			enable = true,
			disable = function(_, buf)
				local max_filesize = 100 * 1024 -- 100 KB
				local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
				if ok and stats and stats.size > max_filesize then
					return true
				end
			end,
			-- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
			-- If you are experiencing weird indenting issues, add the language to
			-- the list of additional_vim_regex_highlighting and disabled languages for indent.
			additional_vim_regex_highlighting = false,
		},
		context_commentstring = {
			config = {
				javascript = {
					__default = "// %s",
					jsx_element = "{/* %s */}",
					jsx_fragment = "{/* %s */}",
					jsx_attribute = "// %s",
					comment = "// %s",
				},
				typescript = { __default = "// %s", __multiline = "/* %s */" },
			},
		},
	},
	config = function(_, opts)
		require("nvim-treesitter.install").prefer_git = true
		require("nvim-treesitter").setup(opts)
	end,
}
