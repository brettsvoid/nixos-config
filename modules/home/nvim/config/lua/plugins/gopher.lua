-- https://github.com/olexsmir/gopher.nvim
return {
	"olexsmir/gopher.nvim",
	ft = "go",
	-- branch = "develop"
	-- (optional) will update plugin's deps on every update
	build = function()
		require("gopher.installer").install_deps({ sync = true })
	end,
	---@type gopher.Config
	opts = {},
}
