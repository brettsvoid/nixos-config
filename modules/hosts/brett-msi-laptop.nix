# MSI GE75 Raider 8SF — NVIDIA RTX 2070 Mobile + Intel UHD 630, btrfs root.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;
in
{
  flake.nixosConfigurations.brett-msi-laptop = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      inputs.ambxst.nixosModules.default
      ../../hardware/msi-laptop.nix
      (
        { pkgs, ... }:
        {
          imports = with config.flake.modules.nixos; [
            agenix
            common
            networking
            users
            firmware
            bluetooth
            thermal
            audio
            nvidia
            nvidia-prime
            fan-control
            greetd
            openssh
            hyprland
            apps-claude-code
            profile-base
            profile-code
            profile-gaming
          ];

          # ─── Identity ──────────────────────────────────────────────────
          networking.hostName = "brett-msi-laptop";

          # ─── Boot ──────────────────────────────────────────────────────
          boot = {
            loader.systemd-boot.enable = true;
            loader.efi.canTouchEfiVariables = true;
            # The swap partition (swapDevices in hardware/msi-laptop.nix).
            resumeDevice = "/dev/disk/by-uuid/25600515-f258-4484-9f54-883db5a8d31d";
            # Early KMS: NVIDIA modules in the initrd for a clean DRM handoff
            # to the compositor.
            initrd.kernelModules = [
              "nvidia"
              "nvidia_modeset"
              "nvidia_uvm"
              "nvidia_drm"
            ];
          };

          # ─── GPU ───────────────────────────────────────────────────────
          # Proprietary kernel module (each host chooses; see nvidia.nix).
          hardware.nvidia.open = false;

          # ─── State version ─────────────────────────────────────────────
          # Pinned at install time; don't change it without reading
          # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
          system.stateVersion = "25.11";

          # ─── Host-specific systemd services ────────────────────────────
          # Writes AQ_DRM_DEVICES (NVIDIA first, then Intel) to a Hyprland
          # config fragment at boot, resolving cardN from the stable PCI
          # addresses. Sourced by the Home Manager block below.
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

          # Re-enable monitors after suspend/hibernate by forcing a modeset.
          systemd.services.hyprland-resume-monitors = {
            description = "Re-enable Hyprland monitors after resume";
            after = [
              "nvidia-resume.service"
              "systemd-suspend.service"
              "systemd-hibernate.service"
            ];
            wantedBy = [ "post-resume.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = username;
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

          # ─── Home Manager wiring ───────────────────────────────────────
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = { inherit inputs; };
            users.${username} = {
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
                desktop-wallpapers
                desktop-custom-shell
                desktop-game-mode
                desktop-screenshots
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

              wayland.windowManager.hyprland.settings.monitor = [
                "DP-1, 2560x1440@165, 1920x0, 1" # external monitor (right)
                "eDP-1, 1920x1080@144, 0x0, 1" # laptop (left, always at origin)
              ];

              # Force linear blitting for the cross-GPU buffer copy (NVIDIA →
              # Intel-driven eDP).
              wayland.windowManager.hyprland.settings.env = [
                "AQ_FORCE_LINEAR_BLIT, 1"
              ];

              # Written at boot by hyprland-drm-config above.
              wayland.windowManager.hyprland.extraConfig = ''
                source = /tmp/hypr-drm-devices.conf
              '';

              # 1–5 on the external monitor, 6–10 on the panel. persistent:true
              # keeps a workspace alive while its monitor is absent, so apps
              # land on the other screen rather than an invisible orphan.
              wayland.windowManager.hyprland.settings.workspace = [
                "1, monitor:DP-1, default:true, persistent:true"
                "2, monitor:DP-1, persistent:true"
                "3, monitor:DP-1, persistent:true"
                "4, monitor:DP-1, persistent:true"
                "5, monitor:DP-1, persistent:true"
                "6, monitor:eDP-1, default:true, persistent:true"
                "7, monitor:eDP-1, persistent:true"
                "8, monitor:eDP-1, persistent:true"
                "9, monitor:eDP-1, persistent:true"
                "10, monitor:eDP-1, persistent:true"
              ];
            };
          };
        }
      )
    ];
  };
}
