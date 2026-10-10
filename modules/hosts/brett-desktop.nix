# MSI MAG Z590 Tomahawk WiFi desktop: i7-11700K, RTX 3080 Ti, btrfs root on
# a Crucial P1 NVMe. Dual-boots Windows from a second NVMe. Hyprland with
# Caelestia (`toggle-shell` swaps in ambxst or the custom shell), plus the
# gaming profile.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;

  # Matched by EDID description (from `hyprctl monitors`), not connector, so
  # swapping DP cables does not reshuffle the layout. The Dell's serial
  # starts with "#", which hyprlang reads as a comment unless doubled; a
  # single "#" silently matches nothing.
  odyssey = "desc:Samsung Electric Company Odyssey G5 HK7X700060";
  dell = "desc:Dell Inc. Dell AW2518H ##ASO0Wsxq3xLd";

  # The 3080 Ti's PCI address.
  dgpu = "0000:01:00.0";
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
          syncthing
          hyprland
          apps-claude-code
          apps-comfyui
          apps-keymapp
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
          # Windows has its own ESP on the P5 Plus, which systemd-boot can't
          # auto-detect, so this chain-loads it through the EDK2 shell. HD3b
          # is the shell's handle for that ESP (PARTUUID d5653750-…). Adding
          # or removing drives can change it: re-run `map -b` in the shell.
          loader.systemd-boot.windows.windows = {
            title = "Windows";
            efiDeviceHandle = "HD3b";
          };
          loader.systemd-boot.edk2-uefi-shell.enable = true;
          # Early KMS: NVIDIA modules in the initrd for a clean DRM handoff
          # to the compositor.
          initrd.kernelModules = [
            "nvidia"
            "nvidia_modeset"
            "nvidia_uvm"
            "nvidia_drm"
            "pci_stub"
          ];
          # Park the chipset's HD Audio controller (00:1f.3, 8086:43c8) on
          # pci-stub. Its only codec is the unused iGPU's HDMI audio, and
          # under snd_hda_intel it times out probing a phantom codec, falls
          # back to the shared IRQ 16, and later the kernel prints
          # "Disabling IRQ #16" over the login prompt. pci_stub is in the
          # initrd so it claims the device before udev loads snd_hda_intel.
          kernelParams = [ "pci-stub.ids=8086:43c8" ];
        };

        # Windows keeps the hardware clock in local time; match it, or the
        # clock is off by the UTC offset after every switch between the two.
        time.hardwareClockInLocalTime = true;

        # ─── GPU ───────────────────────────────────────────────────────
        # Ampere, so the open kernel modules apply. The iGPU drives nothing,
        # hence no nvidia-prime.
        hardware.nvidia.open = true;

        # Stable name for the 3080 Ti's DRM node, for AQ_DRM_DEVICES below:
        # cardN numbering is not stable, and the by-path names contain
        # colons, AQ_DRM_DEVICES' list separator.
        services.udev.extraRules = ''
          KERNEL=="card*", KERNELS=="${dgpu}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
        '';

        # ─── Memory ────────────────────────────────────────────────────
        # Compressed swap in RAM (zstd, up to half of the 32 GB). No swap
        # partition, as the desktop never hibernates.
        zramSwap.enable = true;

        # ─── SSH ───────────────────────────────────────────────────────
        # Merged with the shared list in system/authorized-keys.nix.
        users.users.${username}.openssh.authorizedKeys.keys = [
          # M1 MacBook Pro (~/.ssh/id_ed25519)
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJhQfp9LetOa7O9CFPmT37OjcUPDwr1qMPnBGApe5hM brettsvoid@gmail.com"
        ];

        # ─── State version ─────────────────────────────────────────────
        # Pinned at install time; don't change it without reading
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
                desktop-wallpapers
                desktop-custom-shell
                desktop-caelestia
                desktop-session-restore
                desktop-game-launcher
                desktop-game-mode
                desktop-screenshots
                desktop-window-dissolve
                nvim
                apps-firefox
                apps-git
                apps-ssh
                apps-cursor
                apps-spotify
                apps-godot
                apps-fonts
                apps-claude-code
                apps-comfyui
                apps-keymapp
                apps-nolvus
                profile-base
                profile-code
                profile-gaming
              ];
              home = {
                inherit username;
                homeDirectory = "/home/brett";
              };

              # XDG profile path from the start: this home has no ~/.mozilla to
              # migrate (unlike the laptop, see docs/TODO.md), and
              # home.stateVersion "24.11" would otherwise keep the legacy path.
              programs.firefox.configPath = ".config/mozilla/firefox";

              # Render only on the 3080 Ti; the iGPU drives nothing. The
              # symlink comes from the udev rule above.
              wayland.windowManager.hyprland.settings.env = [
                "AQ_DRM_DEVICES, /dev/dri/nvidia-dgpu"
              ];

              # MangoHud lists the idle iGPU too; show only the 3080 Ti.
              programs.mangohud.settings.pci_dev = dgpu;

              # Odyssey G5 on the left; Dell AW2518H on the right, turned 90°
              # clockwise (transform 1 rotates the picture back). The Odyssey
              # sits 240 px down to centre it on the 1920-tall Dell. The Dell's
              # EDID prefers 60 Hz, so 240 Hz has to be asked for.
              wayland.windowManager.hyprland.settings.monitor = [
                "${odyssey}, 2560x1440@165, 0x240, 1"
                "${dell}, 1920x1080@240, 2560x0, 1, transform, 1"
              ];

              # XWayland games (CS2 among them) size themselves to X's first
              # monitor, which is the rotated Dell unless a primary is set, so
              # make the Odyssey primary. XWayland drops the primary when the
              # KVM switches away and back, so redo it on every monitoradded
              # event. xrandr exits 0 for an output XWayland doesn't have yet,
              # so success is checked in its monitor list, with retries.
              wayland.windowManager.hyprland.settings.exec-once = [
                (lib.getExe (
                  pkgs.writeShellApplication {
                    name = "xwayland-primary-odyssey";
                    runtimeInputs = [
                      pkgs.gnugrep
                      pkgs.jq
                      pkgs.socat
                      pkgs.xrandr
                    ];
                    text = ''
                      set_primary() {
                        for _ in $(seq 30); do
                          output=$(hyprctl -j monitors | jq -r --arg d ${lib.escapeShellArg (lib.removePrefix "desc:" odyssey)} '.[] | select(.description == $d) | .name') || true
                          if [ -n "$output" ]; then
                            xrandr --output "$output" --primary 2>/dev/null || true
                            monitors=$(xrandr --listmonitors 2>/dev/null) || true
                            grep -q "^ *[0-9]*: +\*$output " <<<"$monitors" && return 0
                          fi
                          sleep 1
                        done
                        echo "could not make the Odyssey XWayland's primary output" >&2
                      }

                      set_primary
                      socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
                        while read -r event; do
                          case $event in
                            'monitoradded>>'*) set_primary ;;
                          esac
                        done
                    '';
                  }
                ))
              ];

              # 1–5 on the Odyssey, 6–10 on the Dell. persistent:true keeps a
              # workspace alive while its monitor is off, so apps land on the
              # other screen rather than an invisible orphan.
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
