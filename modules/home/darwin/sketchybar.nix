# sketchybar status bar config. Symlinks ~/.config/sketchybar → repo so the
# whole config tree stays editable in place.
#
# The one value that must stay in sync with AeroSpace's window gaps — the bar
# height (EXTERNAL_BAR_HEIGHT) — is single-sourced in Nix as
# flake.lib.barGeometry (modules/home/darwin/bar-geometry.nix) and rendered to
# ~/.config/sketchybar-vars.sh here. config.sh sources that file, so changing
# the height needs a rebuild; everything else in the dir is read straight off
# disk.
#
# The helper/ subdir contains a small C program that exports CPU stats
# to sketchybar via the SketchyBar event API. The compiled `helper`
# binary committed here is Mach-O arm64; if you ever need to rebuild:
#   cd modules/home/darwin/sketchybar/helper && make
#
# The daemon does NOT run: edgebar (apps/edgebar) replaced it, and the only
# `services.sketchybar` left in the repo is the commented-out block in
# modules/system/darwin/window-manager-aerospace.nix. This home module is kept
# on purpose all the same — the config tree is the reference edgebar is being
# ported from, and the symlink keeps it editable for a side-by-side comparison
# or a future re-enable. Nothing here starts, reloads or even installs
# sketchybar — re-enabling means uncommenting that services block, and a
# `sketchybar --reload` after a geometry change would then be manual.
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
