-- nixd — evaluation-driven Nix LSP. Unlike nil (static lints), nixd links the
-- real Nix evaluator, so the `nixpkgs`/`options` exprs below unlock:
--   • option completion (services.*, programs.*, home.*) with types/defaults
--   • hover docs and goto-definition into nixpkgs / home-manager sources
--   • package completion under `with pkgs; [ ... ]`
-- The exprs are evaluated impurely via builtins.getFlake on this repo; each was
-- checked with `nix eval` before being committed.
local flake = '(builtins.getFlake "' .. os.getenv("HOME") .. '/nixos-config")'

-- Map hostname -> the flake attribute holding *this* machine's evaluated config,
-- so the laptop doesn't try to evaluate the darwin host (or vice versa).
local hosts = {
	["brett-m1-mbp"] = { kind = "nix-darwin", attr = flake .. ".darwinConfigurations.brett-m1-mbp" },
	["brett-msi-laptop"] = { kind = "nixos", attr = flake .. ".nixosConfigurations.brett-msi-laptop" },
}

local options = {}
local host = hosts[vim.fn.hostname()]
if host then
	-- System options (NixOS or nix-darwin).
	options[host.kind] = { expr = host.attr .. ".options" }
	-- home-manager is wired as a module (home-manager.users.brett), so its
	-- options live under the system option set; getSubOptions unwraps them.
	options["home-manager"] = {
		expr = host.attr .. ".options.home-manager.users.type.getSubOptions []",
	}
end

return {
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
	on_init = function(client)
		client.server_capabilities.documentHighlightProvider = false
	end,
	settings = {
		nixd = {
			nixpkgs = { expr = "import " .. flake .. ".inputs.nixpkgs { }" },
			options = options,
			-- Match the repo's formatter (formatter.nix / git-hooks use
			-- nixfmt-rfc-style), not the previous nixpkgs-fmt.
			formatting = { command = { "nixfmt" } },
		},
	},
}
