# sketchybar status bar config. Symlinks ~/.config/sketchybar → repo so the
# whole config tree stays live-editable (`sketchybar --reload`).
#
# The one value that must stay in sync with AeroSpace's window gaps — the bar
# height (EXTERNAL_BAR_HEIGHT) — is single-sourced in Nix as
# flake.lib.barGeometry (modules/home/darwin/bar-geometry.nix) and rendered to
# ~/.config/sketchybar-vars.sh here. config.sh sources that file. Changing the
# height therefore needs a rebuild; everything else in the dir stays live.
#
# The helper/ subdir contains a small C program that exports CPU stats
# to sketchybar via the SketchyBar event API. The compiled `helper`
# binary committed here is Mach-O arm64; if you ever need to rebuild:
#   cd modules/home/darwin/sketchybar/helper && make
#
# The daemon is owned by nix-darwin's `services.sketchybar` (enabled in the
# active window-manager system module); this home module only manages the
# config tree. Verified single daemon — `launchctl list | grep sketchybar`
# shows org.nixos.sketchybar, no brew plist.
{ config, ... }:
let
  geom = config.flake.lib.barGeometry;
in
{
  flake.modules.homeManager.darwin-sketchybar =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      xdg.configFile."sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/darwin/sketchybar";

      # Sourced by sketchybar/config.sh. Kept outside the symlinked sketchybar
      # dir (home-manager can't write into an out-of-store symlink).
      home.file.".config/sketchybar-vars.sh".text = ''
        # Generated from flake.lib.barGeometry — edit modules/home/darwin/bar-geometry.nix
        EXTERNAL_BAR_HEIGHT=${toString geom.barHeight}
      '';

      # Re-run sketchybarrc on every `darwin-rebuild switch` so a changed
      # EXTERNAL_BAR_HEIGHT (in sketchybar-vars.sh) takes effect — the launchd
      # plist references only the binary, so nix-darwin won't restart the
      # daemon on config changes, and hotload doesn't watch the vars file
      # (it lives outside ~/.config/sketchybar). Runs after writeBoundary so
      # the vars file exists; `|| true` tolerates the daemon not running yet.
      home.activation.reloadSketchybar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.sketchybar}/bin/sketchybar --reload || true
      '';
    };
}
