# System-side Hyprland enablement, xdg portal config, and Wayland-companion
# packages. The user-side wayland.windowManager.hyprland config lives in
# modules/home/desktop/hyprland.nix.
_: {
  flake.modules.nixos.hyprland =
    { pkgs, ... }:
    {
      programs = {
        firefox.enable = true;
        hyprland.enable = true;
        hyprlock.enable = true;
        ambxst.enable = true;
        # File manager; also what Caelestia opens folders with
        # (general.apps.explorer defaults to thunar). Super+E.
        thunar.enable = true;
      };

      # Thunar's companions: gvfs for trash, removable drives and network
      # locations; tumbler for thumbnails (without it Thunar logs
      # "ThunarThumbnailer: … not activatable" and shows none).
      services = {
        gvfs.enable = true;
        tumbler.enable = true;
      };

      xdg.portal.config.common.default = "*";

      environment.systemPackages = with pkgs; [
        ghostty
        waybar
        fuzzel
        mako
        kitty

        # GNOME's Quick Look, behind Space in Thunar (the custom action in
        # home/desktop/hyprland.nix). A system package because `sushi` only
        # asks the session bus to start org.gnome.NautilusPreviewer, and
        # the bus reads service files from the system profile
        # (/etc/dbus-1/session.conf). Unregistered, it failed with "The
        # name is not activatable".
        sushi

        # Theme (used by GTK apps under Hyprland)
        (catppuccin-gtk.override {
          variant = "mocha";
          accents = [ "mauve" ];
        })
        catppuccin-cursors.mochaDark
        catppuccin-papirus-folders
      ];
    };
}
