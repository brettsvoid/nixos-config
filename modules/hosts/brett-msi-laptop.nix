# MSI GE75 Raider 8SF — NVIDIA RTX 2070 Mobile + Intel UHD 630, btrfs root.
{ config, inputs, ... }:
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
            fan-control
            greetd
            openssh
            hyprland
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
            resumeDevice = "/dev/sda2";
            # Early KMS: load NVIDIA modules in initrd for proper DRM handoff
            # to the compositor (avoids tearing/blackout on first session).
            initrd.kernelModules = [
              "nvidia"
              "nvidia_modeset"
              "nvidia_uvm"
              "nvidia_drm"
            ];
          };

          # ─── State version ─────────────────────────────────────────────
          # Pinned at install time; do NOT change without reading
          # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
          system.stateVersion = "25.11";

          # ─── Host-specific systemd services ────────────────────────────
          # Dynamically resolve AQ_DRM_DEVICES by PCI bus ID at boot. Card
          # numbers (/dev/dri/cardN) can change across kernel updates, but PCI
          # addresses (0000:01:00.0 = NVIDIA, 0000:00:02.0 = Intel) are stable.
          # This service generates a Hyprland config fragment that
          # desktop/hyprland.nix sources via `source = ...`. Specific to this
          # MSI GE75 Raider's hybrid GPU setup.
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

          # Re-enable monitors after suspend/hibernate (force modeset via
          # disable + reload).
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

          # ─── Home Manager wiring ───────────────────────────────────────
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = { inherit inputs; };
            users.brett = {
              imports = with config.flake.modules.homeManager; [
                base
                shell-zsh
                shell-aliases
                shell-starship
                shell-tools
                terminals-kitty
                terminals-ghostty
                terminals-tmux
                desktop-hyprland
                desktop-hyprlock
                desktop-ambxst
                desktop-media-player
                desktop-wallpapers
                desktop-custom-shell
                nvim
                apps-firefox
                apps-git
                apps-ssh
                apps-cursor
                apps-spotify
                apps-fonts
                profile-base
                profile-code
                profile-gaming
              ];
              home = {
                username = "brett";
                homeDirectory = "/home/brett";
              };

              # Host-specific Hyprland workspace bindings.
              # DP-1 = external monitor (right), eDP-1 = laptop screen (left).
              # persistent:true keeps each workspace alive even when its monitor
              # is absent — apps land on the available monitor instead of into
              # an invisible orphan, and snap back when DP-1 reconnects.
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
