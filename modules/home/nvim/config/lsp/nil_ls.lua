-- nil — static-analysis Nix LSP, run alongside nixd (evaluation-driven
-- completion). Their lints overlap: nixd also flags unused let bindings and
-- `with`. Formatting is conform's (nixfmt).
return {
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
	settings = {
		["nil"] = {
			nix = {
				-- Only load flake inputs already on disk: never `nix flake archive`
				-- (may use the network), and don't ask each time (the null default).
				flake = { autoArchive = false },
			},
		},
	},
}
