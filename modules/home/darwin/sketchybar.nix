# sketchybar status bar config. Symlinks ~/.config/sketchybar → repo.
# Pick up changes via `sketchybar --reload`.
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
_: {
  flake.modules.homeManager.darwin-sketchybar =
    { config, ... }:
    {
      xdg.configFile."sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/darwin/sketchybar";
    };
}
