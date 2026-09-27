# Godot from nixpkgs rather than the Homebrew cask, following the route
# modules/home/apps/blender.nix documents: the darwin build ships an
# $out/Applications bundle that home-manager's targets.darwin.linkApps
# symlinks into ~/Applications/Home Manager Apps, plus `godot` on PATH.
# On Linux the package ships a .desktop entry, so it shows in the launcher.
#
# Editor settings live outside the store (~/Library/Application Support/Godot
# on darwin, ~/.config/godot on Linux), one editor_settings-<major.minor>.tres
# per series, so upgrades leave the old series' settings alone.
_: {
  flake.modules.homeManager.apps-godot =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.godot ];
    };
}
