{ config, pkgs, ... }:

{
  imports = [ ./shell.nix ./terminals.nix ./hyprland.nix ./hyprlock.nix ./tmux.nix ./dev-tools.nix ./firefox.nix ./media-player.nix ./wallpapers.nix ./ambxst.nix ./custom-shell.nix ./neovim.nix ];

  home.username = "brett";
  home.homeDirectory = "/home/brett";
  home.stateVersion = "24.11"; # match your NixOS version

  home.pointerCursor = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
    gtk.enable = true;
  };

  home.packages = with pkgs; [
    spotify
    nerd-fonts.fira-code
  ];

  programs.home-manager.enable = true;
}
