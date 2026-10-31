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
            tailscale
            hyprland
            apps-claude-code
            profile-base
            profile-code
            profile-gaming
          ];

          # ─── Identity ──────────────────────────────────────────────────
          networking.hostName = "brett-msi-laptop";

          # Context7 API key; see brett-desktop.
          age.secrets.docs-lookup-token = {
            file = "${inputs.secrets}/docs-lookup-token.age";
            owner = username;
            mode = "0400";
          };

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

          # Stable names for the two GPUs, by PCI address, as cardN can swap
          # between boots. AQ_DRM_DEVICES (Home Manager block below) lists
          # NVIDIA first, then Intel.
          services.udev.extraRules = ''
            KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
            KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/intel-igpu"
          '';

          # ─── Host-specific systemd services ────────────────────────────
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
                # Hyprland keeps a directory for every instance since boot, so the
                # first one is not always the running one.
                export PATH=/run/current-system/sw/bin:$PATH
                ${config.flake.lib.liveHyprland pkgs}
                [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

                # Disable laptop monitor to tear down stale framebuffer from Intel iGPU
                /run/current-system/sw/bin/hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'

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
                apps-google-chrome
                apps-blender
                apps-git
                apps-ssh
                apps-cursor
                apps-spotify
                apps-fonts
                apps-worktrunk
                apps-fnm
                apps-claude-code
                apps-rea
                profile-base
                profile-code
                profile-gaming
              ];
              home = {
                inherit username;
                homeDirectory = "/home/brett";
              };

              wayland.windowManager.hyprland = {
                settings = {
                  monitor = [
                    # external monitor (right)
                    {
                      output = "DP-1";
                      mode = "2560x1440@165";
                      position = "1920x0";
                      scale = 1;
                    }
                    # laptop (left, always at origin)
                    {
                      output = "eDP-1";
                      mode = "1920x1080@144";
                      position = "0x0";
                      scale = 1;
                    }
                  ];

                  env = with config.flake.lib.hypr; [
                    # The symlinks come from the udev rules above.
                    (env "AQ_DRM_DEVICES" "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu")
                    # Force linear blitting for the cross-GPU buffer copy (NVIDIA →
                    # Intel-driven eDP).
                    (env "AQ_FORCE_LINEAR_BLIT" "1")
                  ];

                  # 1–5 on the external monitor, 6–10 on the panel. persistent
                  # keeps a workspace alive while its monitor is absent, so apps
                  # land on the other screen rather than an invisible orphan.
                  workspace_rule = builtins.genList (i: {
                    workspace = toString (i + 1);
                    monitor = if i < 5 then "DP-1" else "eDP-1";
                    default = i == 0 || i == 5;
                    persistent = true;
                  }) 10;
                };
              };
            };
          };
        }
      )
    ];
  };
}
