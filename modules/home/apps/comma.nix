# comma (`,`) — run any program from nixpkgs once, without installing it:
#   , cowsay hi
# Backed by the nix-community/nix-index-database flake, which ships a CI-built
# nix-index database (refreshed whenever you `nix flake update`), so there is
# no local `nix-index` run to do and the data never goes stale. It also gives
# a working `command-not-found` handler — the channel-based default can't work
# on a pure-flake system like this one.
{ inputs, ... }:
{
  flake.modules.homeManager.apps-comma = {
    imports = [ inputs.nix-index-database.homeModules.nix-index ];

    # Enable nix-index itself (command-not-found hook + DB wiring)...
    programs.nix-index.enable = true;
    # ...and install `comma`, pointed at the prebuilt database.
    programs.nix-index-database.comma.enable = true;
  };
}
