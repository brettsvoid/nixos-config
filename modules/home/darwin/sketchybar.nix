# sketchybar config. Symlinks ~/.config/sketchybar to the repo so the tree
# stays editable in place. Only the bar height (EXTERNAL_BAR_HEIGHT) comes
# from Nix: it's rendered from flake.lib.barGeometry (bar-geometry.nix) into
# ~/.config/sketchybar-vars.sh, which config.sh sources, so changing it needs
# a rebuild.
#
# helper/ is a small C program that feeds CPU stats to sketchybar; sketchybarrc
# runs `make` there on each start (the committed binary is Mach-O arm64).
#
# The daemon is disabled (edgebar replaced it): re-enabling means uncommenting
# services.sketchybar in modules/system/darwin/window-manager-aerospace.nix.
# This module is kept as the reference edgebar is ported from. Nothing here
# starts, reloads or installs sketchybar, so a re-enabled daemon would need a
# manual `sketchybar --reload` after a geometry change.
{ config, ... }:
let
  geom = config.flake.lib.barGeometry;
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.darwin-sketchybar =
    { config, ... }:
    {
      xdg.configFile."sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/darwin/sketchybar";

      # Sourced by sketchybar/config.sh. Kept outside the symlinked sketchybar
      # dir (home-manager can't write into an out-of-store symlink).
      home.file.".config/sketchybar-vars.sh".text = ''
        # Generated from flake.lib.barGeometry — edit modules/home/darwin/bar-geometry.nix
        EXTERNAL_BAR_HEIGHT=${toString geom.barHeight}
      '';
    };
}
