return {
	settings = {
		Lua = {
			completion = { callSnippet = "Replace" },
			diagnostics = { globals = { "vim", "hs" } },
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
}
