# Catppuccin Mocha pointer cursor (Linux/X11/Wayland). dconf is GNOME-only.
_: {
  flake.modules.homeManager.apps-cursor =
    { lib, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.pointerCursor = {
        name = "catppuccin-mocha-dark-cursors";
        package = pkgs.catppuccin-cursors.mochaDark;
        size = 24;
        gtk.enable = true;
      };
    };
}
