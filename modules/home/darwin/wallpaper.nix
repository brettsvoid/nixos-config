# Sets the macOS desktop picture. nix-darwin has no native wallpaper option,
# and the old `System Events` AppleScript route has been broken since Sonoma,
# so we drive `desktoppr` (NSWorkspace.setDesktopImageURL under the hood).
#
# The image comes from ~/Pictures/Wallpapers, which the `desktop-wallpapers`
# home module populates from modules/home/desktop/wallpapers — so this module
# requires that one to be imported alongside it (done in the host's imports).
# Pointing at the home copy rather than a /nix/store path keeps the wallpaper
# stable across GC and visible in Finder.
_: {
  flake.modules.homeManager.darwin-wallpaper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.desktoppr ];

      # Re-apply on every `darwin-rebuild switch`. entryAfter writeBoundary so
      # the wallpaper file (linked by desktop-wallpapers) exists first.
      home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.desktoppr}/bin/desktoppr all \
          "${config.home.homeDirectory}/Pictures/Wallpapers/chisato_petals_of_silence_4k.jpg" || true
      '';
    };
}
