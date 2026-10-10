# Gaming profile. Linux-heavy (Steam, gamemode, etc.); the homeManager half
# applies cross-platform for the chat-and-launcher pieces.
_: {
  flake.modules.nixos.profile-gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
      };
      programs.gamemode.enable = true;

      # Recent Proton (GE-Proton10-10, for one) syncs Windows threads
      # through /dev/ntsync when it exists, and falls back to fsync
      # otherwise. The kernel builds ntsync as a module but nothing loads
      # it, so load it at boot. Fluorine (Nolvus) also sets
      # PROTON_NO_NTSYNC=1 whenever the device is missing.
      boot.kernelModules = [ "ntsync" ];

      # MangoHud's GPU power is garbage in 32-bit games. Since the 570
      # drivers, NVIDIA's 32-bit NVML returns nonsense from
      # nvmlDeviceGetPowerUsage, with NVML_SUCCESS. The patch computes power
      # from nvmlDeviceGetTotalEnergyConsumption, which is still correct
      # there. Drop it once NVIDIA or MangoHud fixes this (or if it stops
      # applying, check here first):
      # https://github.com/flightlessmango/MangoHud/issues/1607
      # An overlay so pkgsi686Linux.mangohud, the 32-bit half that nixpkgs
      # bundles into mangohud, is patched too.
      nixpkgs.overlays = [
        (_: prev: {
          mangohud = prev.mangohud.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./gaming/mangohud-nvml-energy.patch ];
          });
        })
      ];

      environment.systemPackages = with pkgs; [
        lutris
        heroic
      ];

      # Let MangoHud read CPU package power. The RAPL energy counter has
      # been root-only since CVE-2020-8694 (a power side channel); this
      # opens it to the users group only.
      services.udev.extraRules = ''
        SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/energy_uj", RUN+="${pkgs.coreutils}/bin/chmod g+r /sys%p/energy_uj"
      '';
    };

  flake.modules.homeManager.profile-gaming =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        discord
        prismlauncher
      ];

      # FPS/performance overlay, loaded into every Vulkan game (Proton
      # included) but hidden until toggled. The default toggle,
      # Shift_R+F12, also fires Steam's F12 screenshot.
      programs.mangohud = {
        enable = true;
        settings = {
          no_display = true;
          toggle_hud = "Shift_R+F8";
          # Built-in "horizontal view": one row across the top. Config
          # options override the preset's, which turns frame_timing on.
          preset = 2;
          frame_timing = false;
          font_size = 20; # default 24
          # Trim the preset: without a battery, its battery fields leave
          # empty separators.
          battery = false;
          battery_watt = false;
          battery_time = false;
          # Shift_L+F2 starts and stops a frame-time log (a CSV per run),
          # even with the HUD hidden. Without this, MangoHud writes them
          # loose in $HOME. It does not create the folder, hence the
          # .keep below.
          output_folder = "${config.xdg.stateHome}/mangohud";
        };
      };
      xdg.stateFile."mangohud/.keep".text = "";

      # Set via Hyprland rather than enableSessionWide: Steam is started
      # from Hyprland and does not inherit home.sessionVariables.
      wayland.windowManager.hyprland.settings.env = [ "MANGOHUD, 1" ];
    };
}
