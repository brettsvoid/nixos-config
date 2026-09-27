# MSI MAG Z590 Tomahawk WiFi desktop — i7-11700K, NVIDIA RTX 3080 Ti, btrfs
# root on its own NVMe (Crucial P1). Dual-boots Windows, which lives on a
# different NVMe with its own ESP and has its own entry in the systemd-boot
# menu. Hyprland desktop (greetd + ambxst, with Caelestia on trial via
# `toggle-shell caelestia`) and the gaming profile.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;

  # Monitors are matched by description (make, model, serial from the EDID),
  # not by connector, so swapping DP cables (e.g. to get the BIOS onto the
  # landscape screen) does not reshuffle the layout. Copied from
  # `hyprctl monitors`: the Dell's model string repeats "Dell", and its
  # serial starts with "#", which hyprlang reads as a comment unless it is
  # doubled. Unescaped, the rule silently matched nothing (60 Hz, unrotated).
  odyssey = "desc:Samsung Electric Company Odyssey G5 HK7X700060";
  dell = "desc:Dell Inc. Dell AW2518H ##ASO0Wsxq3xLd";
in
{
  flake.nixosConfigurations.brett-desktop = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      inputs.ambxst.nixosModules.default
      ../../hardware/desktop.nix
      {
        imports = with config.flake.modules.nixos; [
          agenix
          common
          networking
          users
          firmware
          bluetooth
          audio
          nvidia
          greetd
          openssh
          hyprland
          apps-claude-code
          profile-base
          profile-code
          profile-gaming
        ];

        # ─── Identity ──────────────────────────────────────────────────
        networking.hostName = "brett-desktop";

        # ─── Boot ──────────────────────────────────────────────────────
        boot = {
          loader.systemd-boot.enable = true;
          loader.efi.canTouchEfiVariables = true;
          # Windows lives on the P5 Plus with its own ESP, so systemd-boot can't
          # auto-detect it; this entry chain-loads its Bootmgfw.efi through
          # the EDK2 shell. HD3b is the shell's consistent handle for that
          # ESP (the one with PARTUUID d5653750-…). Adding or removing drives
          # can change it: re-run `map -b` in the shell below and update it.
          loader.systemd-boot.windows.windows = {
            title = "Windows";
            efiDeviceHandle = "HD3b";
          };
          loader.systemd-boot.edk2-uefi-shell.enable = true;
          # Early KMS: load NVIDIA modules in initrd for proper DRM handoff
          # to the compositor (avoids tearing/blackout on first session).
          initrd.kernelModules = [
            "nvidia"
            "nvidia_modeset"
            "nvidia_uvm"
            "nvidia_drm"
            "pci_stub"
          ];
          # Park the chipset's HD Audio controller (00:1f.3, 8086:43c8) on
          # pci-stub so snd_hda_intel never drives it. Its only real codec is
          # the iGPU's HDMI audio (the iGPU drives no monitor; the board's
          # analogue jacks are a separate USB device). Every boot it reported
          # a phantom codec at address 0, timed out probing it, fell back from
          # MSI to the shared legacy IRQ 16, and ~90–160 s later the kernel
          # disabled IRQ 16 after 100k unclaimed interrupts, printing
          # "Disabling IRQ #16" (pr_emerg, so over the login prompt at any
          # loglevel). The other drivers on IRQ 16 are ruled out: i801_smbus
          # claims every interrupt its own status bit raises, and the NVMe
          # drives have INTx disabled. pci_stub is in the initrd so it claims
          # the device before udev loads snd_hda_intel in stage 2.
          kernelParams = [ "pci-stub.ids=8086:43c8" ];
        };

        # Windows keeps the hardware clock in local time. Without this the
        # clock is off by the UTC offset after every switch between the two.
        time.hardwareClockInLocalTime = true;

        # ─── GPU ───────────────────────────────────────────────────────
        # RTX 3080 Ti is Ampere, so the open kernel modules apply. Both
        # monitors are on the NVIDIA card and the iGPU drives nothing, hence
        # no nvidia-prime.
        hardware.nvidia.open = true;

        # Stable name for the 3080 Ti's DRM node, for AQ_DRM_DEVICES below.
        # /dev/dri/cardN numbering is not stable (it was card0 in the
        # installer and card1 after install), and the by-path names contain
        # colons, which AQ_DRM_DEVICES uses as its list separator.
        services.udev.extraRules = ''
          KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
        '';

        # ─── Memory ────────────────────────────────────────────────────
        # Compressed swap in RAM (zstd, up to 50% of the 32 GB). No swap
        # partition: a desktop has no need to hibernate.
        zramSwap.enable = true;

        # ─── SSH ───────────────────────────────────────────────────────
        # Merged with the shared list in system/authorized-keys.nix.
        users.users.${username}.openssh.authorizedKeys.keys = [
          # M1 MacBook Pro (~/.ssh/id_ed25519)
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJhQfp9LetOa7O9CFPmT37OjcUPDwr1qMPnBGApe5hM brettsvoid@gmail.com"
        ];

        # ─── State version ─────────────────────────────────────────────
        # Pinned at install time; do NOT change without reading
        # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        system.stateVersion = "26.05";

        # ─── Home Manager wiring ───────────────────────────────────────
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = { inherit inputs; };
          users.${username} =
            { lib, pkgs, ... }:
            {
              imports = with config.flake.modules.homeManager; [
                base
                shell-zsh
                shell-aliases
                shell-starship
                shell-tools
                apps-nh
                terminals-kitty
                terminals-ghostty
                terminals-tmux
                terminals-herdr
                desktop-hyprland
                desktop-hyprlock
                desktop-ambxst
                desktop-media-player
                desktop-wallpapers
                desktop-custom-shell
                desktop-caelestia
                desktop-game-launcher
                nvim
                apps-firefox
                apps-git
                apps-ssh
                apps-cursor
                apps-spotify
                apps-fonts
                apps-claude-code
                profile-base
                profile-code
                profile-gaming
              ];
              home = {
                inherit username;
                homeDirectory = "/home/brett";
              };

              # Firefox profile under XDG from the start. This home was new at
              # install, so there is no ~/.mozilla to migrate (see the laptop's
              # entry in docs/TODO.md), and home.stateVersion "24.11" would
              # otherwise keep the legacy path.
              programs.firefox.configPath = ".config/mozilla/firefox";

              # Render only on the 3080 Ti. It drives both monitors; the iGPU
              # drives nothing, so it is left out entirely. The symlink comes
              # from the udev rule above.
              wayland.windowManager.hyprland.settings.env = [
                "AQ_DRM_DEVICES, /dev/dri/nvidia-dgpu"
              ];

              # Odyssey G5 (27", landscape) on the left; Dell AW2518H (24.5")
              # on the right, turned 90° clockwise so its top edge faces right.
              # transform 1 rotates the picture 90° counter-clockwise to match.
              # Rotated, the Dell is 1080x1920; the Odyssey sits 240 px down so
              # the two are centred on each other. The Dell's EDID prefers
              # 60 Hz, so its 240 Hz mode has to be asked for.
              wayland.windowManager.hyprland.settings.monitor = [
                "${odyssey}, 2560x1440@165, 0x240, 1"
                "${dell}, 1920x1080@240, 2560x0, 1, transform, 1"
              ];

              # XWayland games (CS2 among them) size themselves to X's first
              # monitor. With no primary set, XWayland lists the Dell first, so
              # they render at the rotated 1080x1920 and fill only the left of
              # the Odyssey. Make the Odyssey primary; its connector is looked
              # up by description so a cable swap still does not matter. The
              # loop waits for XWayland in case it is not up yet.
              wayland.windowManager.hyprland.settings.exec-once = [
                (lib.getExe (
                  pkgs.writeShellApplication {
                    name = "xwayland-primary-odyssey";
                    runtimeInputs = [
                      pkgs.jq
                      pkgs.xrandr
                    ];
                    text = ''
                      output=$(hyprctl -j monitors | jq -r --arg d ${lib.escapeShellArg (lib.removePrefix "desc:" odyssey)} '.[] | select(.description == $d) | .name')
                      for _ in $(seq 30); do
                        xrandr --output "$output" --primary 2>/dev/null && exit 0
                        sleep 1
                      done
                      exit 1
                    '';
                  }
                ))
              ];

              # 1–5 on the Odyssey, 6–10 on the Dell. persistent:true keeps a
              # workspace alive while its monitor is off, so apps land on the
              # other screen instead of an invisible orphan.
              wayland.windowManager.hyprland.settings.workspace = [
                "1, monitor:${odyssey}, default:true, persistent:true"
                "2, monitor:${odyssey}, persistent:true"
                "3, monitor:${odyssey}, persistent:true"
                "4, monitor:${odyssey}, persistent:true"
                "5, monitor:${odyssey}, persistent:true"
                "6, monitor:${dell}, default:true, persistent:true"
                "7, monitor:${dell}, persistent:true"
                "8, monitor:${dell}, persistent:true"
                "9, monitor:${dell}, persistent:true"
                "10, monitor:${dell}, persistent:true"
              ];
            };
        };
      }
    ];
  };
}
