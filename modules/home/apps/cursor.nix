# Catppuccin Mocha pointer cursor (Linux/X11/Wayland). dconf is GNOME-only.
_: {
  flake.modules.homeManager.apps-cursor =
    { lib, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.pointerCursor = {
        # Explicit since home-manager deprecated inferring "enabled" from the
        # mere presence of home.pointerCursor settings. No behaviour change —
        # it was already implicitly on.
        enable = true;
        name = "catppuccin-mocha-dark-cursors";
        package = pkgs.catppuccin-cursors.mochaDark;
        size = 24;
        gtk.enable = true;
      };
    };
}
