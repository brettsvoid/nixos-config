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
      };

      xdg.portal.config.common.default = "*";

      environment.systemPackages = with pkgs; [
        ghostty
        waybar
        fuzzel
        mako
        kitty

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
