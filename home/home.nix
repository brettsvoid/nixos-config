{ config, pkgs, ... }:

{
  imports = [ ./shell.nix ./terminals.nix ./hyprland.nix ./tmux.nix ./dev-tools.nix ./firefox.nix ./media-player.nix ./wallpapers.nix ];

  home.username = "brett";
  home.homeDirectory = "/home/brett";
  home.stateVersion = "24.11"; # match your NixOS version

  home.pointerCursor = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
    gtk.enable = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = "catppuccin-mocha-dark-cursors";
    cursor-size = 24;
  };

  programs.home-manager.enable = true;
}
