# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/audio.nix
      ../../modules/nvidia.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Hibernation
  boot.resumeDevice = "/dev/sda2";

  networking.hostName = "brett-msi-laptop"; 

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.brett = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };

  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;
  programs.firefox.enable = true;
  programs.niri.enable = true;
  programs.hyprland.enable = true;
  programs.ambxst.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim 
    git
    wget
    neovim
    ghostty
    # Useful companions for niri
    waybar
    fuzzel
    mako
    kitty
    swaylock
    # Theme
    (catppuccin-gtk.override {
      variant = "mocha";
      accents = [ "mauve" ];
    })
    catppuccin-cursors.mochaDark
    catppuccin-papirus-folders  # icon theme
    gnomeExtensions.user-themes
  ];
  
  # Firmware (helps with hardware quirks)
  hardware.enableAllFirmware = true;

  # Fan control
  hardware.sensor.iio.enable = true;
  services.thermald.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;

  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

