return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	-- No build step / no require("nvim-treesitter").install(...): parsers are
	-- provided prebuilt by Nix (modules/home/nvim/default.nix → treesitterParsers,
	-- symlinked onto rtp at ~/.config/nvim/parser). This plugin is kept only for
	-- its queries, ft→lang aliases, and indentexpr. The authoritative parser list
	-- now lives in default.nix.
	config = function()
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local buf = args.buf
				local max_filesize = 100 * 1024
				local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
				if ok and stats and stats.size > max_filesize then
					return
				end
				pcall(vim.treesitter.start, buf)

				-- treesitter-powered indentation
				-- (the main branch doesn't set this up automatically; folding is
				-- configured globally in core/options.lua via vim.treesitter.foldexpr)
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
