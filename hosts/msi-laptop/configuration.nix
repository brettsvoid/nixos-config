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
      ../../modules/fan-control.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Hibernation
  boot.resumeDevice = "/dev/sda2";
  # Early KMS: load NVIDIA modules in initrd for proper DRM handoff to compositor
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  networking.hostName = "brett-msi-laptop"; 

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Needed for services.xserver.videoDrivers (NVIDIA module)
  services.xserver.enable = true;

  services.greetd = let
    sessions = pkgs.linkFarm "greeter-sessions" [
      { name = "hyprland.desktop"; path = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop"; }
      { name = "niri.desktop"; path = "${pkgs.niri}/share/wayland-sessions/niri.desktop"; }
    ];
  in {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${sessions}";
      user = "greeter";
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.brett = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" ];
    shell = pkgs.zsh;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.ssh.startAgent = true;
  programs.zsh.enable = true;
  programs.firefox.enable = true;
  programs.niri.enable = true;
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  programs.ambxst.enable = true;

  xdg.portal.config.common.default = "*";

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim 
    git
    wget
    ghostty
    # Useful companions for niri
    waybar
    fuzzel
    mako
    kitty
    # Theme
    (catppuccin-gtk.override {
      variant = "mocha";
      accents = [ "mauve" ];
    })
    catppuccin-cursors.mochaDark
    catppuccin-papirus-folders  # icon theme
    lm_sensors
  ];
  
  # Firmware (helps with hardware quirks)
  hardware.enableAllFirmware = true;

  # Fan control
  hardware.sensor.iio.enable = true;
  services.thermald.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Bluetooth
  hardware.bluetooth.enable = true;

  # Dynamically resolve AQ_DRM_DEVICES by PCI bus ID at boot.
  # Card numbers (/dev/dri/cardN) can change across kernel updates, but PCI addresses
  # (0000:01:00.0 = NVIDIA, 0000:00:02.0 = Intel) are stable. This service generates
  # a Hyprland config fragment that hyprland.nix sources via `source = ...`.
  # Specific to this MSI GE75 Raider's hybrid GPU setup (NVIDIA RTX 2070 + Intel UHD 630).
  systemd.services.hyprland-drm-config = {
    description = "Generate Hyprland DRM device config from PCI bus IDs";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "gen-hypr-drm" ''
        for card in /dev/dri/card*; do
          name=$(basename "$card")
          bus=$(readlink -f "/sys/class/drm/$name/device" 2>/dev/null)
          case "$bus" in
            */0000:01:00.0) nvidia="$card" ;;  # NVIDIA RTX 2070 Mobile
            */0000:00:02.0) intel="$card" ;;   # Intel UHD 630
          esac
        done
        echo "env = AQ_DRM_DEVICES,''${nvidia:-/dev/dri/card0}:''${intel:-/dev/dri/card1}" > /tmp/hypr-drm-devices.conf
        chmod 644 /tmp/hypr-drm-devices.conf
      '';
    };
  };

  # Re-enable monitors after suspend/hibernate (force modeset via disable + reload)
  systemd.services.hyprland-resume-monitors = {
    description = "Re-enable Hyprland monitors after resume";
    after = [ "nvidia-resume.service" "systemd-suspend.service" "systemd-hibernate.service" ];
    wantedBy = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "brett";
      ExecStart = pkgs.writeShellScript "hyprland-resume-monitors" ''
        INSTANCE_DIR="/run/user/1000/hypr"
        [ ! -d "$INSTANCE_DIR" ] && exit 0
        INSTANCE=$(ls "$INSTANCE_DIR" | head -1)
        [ -z "$INSTANCE" ] && exit 0
        export HYPRLAND_INSTANCE_SIGNATURE="$INSTANCE"

        # Disable laptop monitor to tear down stale framebuffer from Intel iGPU
        /run/current-system/sw/bin/hyprctl keyword monitor "eDP-1,disable"

        # Reload config — re-applies all monitor rules, forcing fresh modesets
        /run/current-system/sw/bin/hyprctl reload
      '';
    };
  };

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

