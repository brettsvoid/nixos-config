-- nixd — evaluation-driven Nix LSP. The `nixpkgs`/`options` exprs below
-- (evaluated impurely via builtins.getFlake on this repo) give option and
-- package completion, hover docs and goto-definition into nixpkgs/home-manager.
local flake = '(builtins.getFlake "' .. os.getenv("HOME") .. '/nixos-config")'

-- Hostname -> this machine's evaluated config, so each host only evaluates its
-- own system. Unlisted hosts get no option completion.
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
			-- Match formatter.nix and the git-hooks pre-commit.
			formatting = { command = { "nixfmt" } },
		},
	},
}
