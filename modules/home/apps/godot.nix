# Godot from nixpkgs rather than the Homebrew cask, following the route
# modules/home/apps/blender.nix documents: the darwin build ships an
# $out/Applications bundle that home-manager's targets.darwin.linkApps
# symlinks into ~/Applications/Home Manager Apps, plus `godot` on PATH.
#
# Editor settings live in ~/Library/Application Support/Godot, outside the
# store, one editor_settings-<major.minor>.tres per series, so upgrades
# leave the old series' settings alone.
_: {
  flake.modules.homeManager.apps-godot =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.godot ];
    };
}
