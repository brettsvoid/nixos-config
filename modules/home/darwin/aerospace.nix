# AeroSpace config. aerospace.toml is generated from aerospace/aerospace.toml.in
# by substituting @outerTop@ from flake.lib.barGeometry (the single source of
# the bar height, shared with sketchybar — see modules/home/darwin/bar-geometry.nix).
#
# AeroSpace's TOML can't reference variables, so this is the only way to keep
# the window gap in sync with the bar height. Trade-off vs the old
# mkOutOfStoreSymlink: edits now need `darwin-rebuild switch` before
# `aerospace reload-config` (the file is no longer live-edited in place).
#
# Pair this module with `flake.modules.darwin.window-manager-aerospace`,
# which installs the package + launchd agent.
#
# Swapping with the yabai stack: in modules/hosts/brett-m1-mbp.nix, replace
# the `darwin-yabai` / `darwin-skhd` imports with `darwin-aerospace` and
# the system module `window-manager` with `window-manager-aerospace`.
{ config, ... }:
let
  geom = config.flake.lib.barGeometry;
in
{
  flake.modules.homeManager.darwin-aerospace =
    { pkgs, ... }:
    {
      xdg.configFile."aerospace/aerospace.toml".source = pkgs.replaceVars ./aerospace/aerospace.toml.in {
        outerTop = toString geom.outerTop;
      };
    };
}
