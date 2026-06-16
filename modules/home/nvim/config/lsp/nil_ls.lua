-- nil — static-analysis Nix LSP (oxalica/nil), runs alongside nixd.
-- nil contributes the lints nixd lacks (unused let bindings, unused `with`,
-- dead code, deprecated syntax); nixd contributes evaluation-driven
-- completion. Formatting is owned by conform (nixpkgs_fmt), so nil's
-- formatting capability is never invoked here.
return {
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
	settings = {
		["nil"] = {
			nix = {
				-- Don't copy flake inputs into the store just to analyze; keeps
				-- nil fast and avoids surprise network/store churn on open.
				flake = { autoArchive = false },
			},
		},
	},
}
