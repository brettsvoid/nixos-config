# AeroSpace config — symlinks ~/.config/aerospace → repo so edits take
# effect on `aerospace reload-config` (no rebuild required).
#
# Pair this module with `flake.modules.darwin.window-manager-aerospace`,
# which installs the package + launchd agent. Keeping the config in
# home-manager (like darwin-yabai) means the TOML can be edited live.
#
# Swapping with the yabai stack: in modules/hosts/brett-m1-mbp.nix, replace
# the `darwin-yabai` / `darwin-skhd` imports with `darwin-aerospace` and
# the system module `window-manager` with `window-manager-aerospace`.
_: {
  flake.modules.homeManager.darwin-aerospace =
    { config, ... }:
    {
      xdg.configFile."aerospace".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/darwin/aerospace";
    };
}
