-- https://github.com/olexsmir/gopher.nvim
return {
	"olexsmir/gopher.nvim",
	ft = "go",
	-- branch = "develop"
	-- No `build` hook: its deps come from nvim's extraPackages in
	-- modules/home/nvim/default.nix instead of `go install`.
	---@type gopher.Config
	opts = {},
}
