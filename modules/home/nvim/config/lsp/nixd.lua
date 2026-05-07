return {
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
	on_init = function(client)
		client.server_capabilities.documentHighlightProvider = false
	end,
	settings = {
		nixd = {
			formatting = { command = { "nixpkgs-fmt" } },
		},
	},
}
