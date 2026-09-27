# MSI MAG Z590 Tomahawk WiFi desktop — i7-11700K, NVIDIA RTX 3080 Ti, btrfs
# root on its own NVMe (Crucial P1). Dual-boots Windows, which lives on a
# different NVMe with its own ESP; pick it from the firmware boot menu (F11).
#
# CLI-only for now. The desktop stack (greetd, Hyprland, ambxst) and
# profile-gaming come next, once modules/home/desktop/hyprland.nix stops
# hard-coding the laptop's monitors and Optimus workarounds.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;
in
{
  flake.nixosConfigurations.brett-desktop = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
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
          openssh
          profile-base
          profile-code
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
          ];
        };

        # Windows keeps the hardware clock in local time. Without this the
        # clock is off by the UTC offset after every switch between the two.
        time.hardwareClockInLocalTime = true;

        # ─── GPU ───────────────────────────────────────────────────────
        # RTX 3080 Ti is Ampere, so the open kernel modules apply. Both
        # monitors are on the NVIDIA card and the iGPU drives nothing, hence
        # no nvidia-prime.
        hardware.nvidia.open = true;

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
          users.${username} = {
            imports = with config.flake.modules.homeManager; [
              base
              shell-zsh
              shell-aliases
              shell-starship
              shell-tools
              apps-nh
              terminals-tmux
              terminals-herdr
              nvim
              apps-git
              apps-ssh
              profile-base
              profile-code
            ];
            home = {
              inherit username;
              homeDirectory = "/home/brett";
            };
          };
        };
      }
    ];
  };
}
