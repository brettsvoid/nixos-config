{ config, pkgs, ... }:

{
  imports = [ ./shell.nix ./terminals.nix ./hyprland.nix ./tmux.nix ];

  home.username = "brett";
  home.homeDirectory = "/home/brett";
  home.stateVersion = "24.11"; # match your NixOS version

  programs.home-manager.enable = true;
}
