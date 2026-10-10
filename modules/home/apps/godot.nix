# Godot from nixpkgs rather than the Homebrew cask, by the same route as
# modules/home/apps/blender.nix: on darwin, linkApps puts the app bundle in
# ~/Applications/Home Manager Apps; on Linux it ships a .desktop entry.
#
# Editor settings live outside the store (~/Library/Application Support/Godot
# on darwin, ~/.config/godot on Linux), one editor_settings-<major.minor>.tres
# per series.
_: {
  flake.modules.homeManager.apps-godot =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.godot ];
    };
}
