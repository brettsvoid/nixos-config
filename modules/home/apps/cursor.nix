# Catppuccin Mocha pointer cursor, Linux only.
_: {
  flake.modules.homeManager.apps-cursor =
    { lib, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.pointerCursor = {
        # Explicit: home-manager deprecated inferring it from the other
        # home.pointerCursor settings.
        enable = true;
        name = "catppuccin-mocha-dark-cursors";
        package = pkgs.catppuccin-cursors.mochaDark;
        size = 24;
        gtk.enable = true;
      };
    };
}
