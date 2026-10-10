# comma (`,`): run any program from nixpkgs once, without installing it:
#   , cowsay hi
# The nix-index-database flake input ships a CI-built database, refreshed
# when that input is updated, so there is no local `nix-index` run. It also
# gives a working `command-not-found` handler, which the channel-based
# default cannot on a flake-only system.
{ inputs, ... }:
{
  flake.modules.homeManager.apps-comma = {
    imports = [ inputs.nix-index-database.homeModules.nix-index ];

    # The command-not-found hook and database wiring.
    programs.nix-index.enable = true;
    # `comma`, pointed at the prebuilt database.
    programs.nix-index-database.comma.enable = true;
  };
}
