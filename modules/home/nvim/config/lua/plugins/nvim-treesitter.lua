return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	-- No build step or install(): parsers and queries come prebuilt from Nix
	-- (modules/home/nvim/default.nix). Kept for ft→lang aliases, indentexpr and
	-- the query predicates its queries use.
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

				-- The main branch doesn't set indentexpr itself. Folding is set in
				-- core/options.lua.
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
