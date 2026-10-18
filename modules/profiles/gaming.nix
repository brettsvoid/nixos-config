# Gaming: Steam, gamemode, launchers and MangoHud. Linux only; the
# home-manager half is a no-op elsewhere.
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
      # through /dev/ntsync when it exists, else fsync, and Fluorine (Nolvus)
      # sets PROTON_NO_NTSYNC=1 without it. The kernel builds ntsync as a
      # module that nothing loads, so load it at boot.
      boot.kernelModules = [ "ntsync" ];

      # Since the 570 drivers, NVIDIA's 32-bit NVML returns nonsense from
      # nvmlDeviceGetPowerUsage, so MangoHud's GPU power is wrong in 32-bit
      # games. The patch derives power from
      # nvmlDeviceGetTotalEnergyConsumption instead. An overlay, so the
      # 32-bit half nixpkgs bundles into mangohud is patched too. Drop it
      # once fixed upstream; if it stops applying, check the issue first:
      # https://github.com/flightlessmango/MangoHud/issues/1607
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

      # Let MangoHud read CPU package power. The RAPL energy counter is
      # root-only since CVE-2020-8694 (a power side channel); this opens it
      # to the users group.
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

      # Performance overlay in every Vulkan game (Proton included), hidden
      # until toggled. Not the default Shift_R+F12, which also fires Steam's
      # F12 screenshot.
      programs.mangohud = {
        enable = true;
        settings = {
          no_display = true;
          toggle_hud = "Shift_R+F8";
          # Built-in "horizontal view", one row across the top. Options set
          # here override the preset's (it turns frame_timing on).
          preset = 2;
          frame_timing = false;
          font_size = 20; # default 24
          # Without a battery, the preset's battery fields leave empty
          # separators.
          battery = false;
          battery_watt = false;
          battery_time = false;
          # For the frame-time logs Shift_L+F2 starts and stops (a CSV per
          # run, even with the HUD hidden), which otherwise land in $HOME.
          # MangoHud doesn't create the folder, hence the .keep below.
          output_folder = "${config.xdg.stateHome}/mangohud";
        };
      };
      xdg.stateFile."mangohud/.keep".text = "";

      # Set via Hyprland rather than enableSessionWide: Steam is started
      # from Hyprland and does not inherit home.sessionVariables.
      wayland.windowManager.hyprland.settings.env = [ "MANGOHUD, 1" ];
    };
}
