return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	-- No build step or install(): parsers come prebuilt from Nix (treesitterParsers
	-- in modules/home/nvim/default.nix, linked to ~/.config/nvim/parser). Kept for
	-- ft→lang aliases and indentexpr; its queries reach the rtp only via
	-- :TSInstall, which isn't run.
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
