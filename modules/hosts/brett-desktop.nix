# MSI MAG Z590 Tomahawk WiFi desktop: i7-11700K, RTX 3080 Ti, btrfs root on
# a Crucial P1 NVMe. Dual-boots Windows from a second NVMe. Hyprland with
# Caelestia (`toggle-shell` swaps in ambxst or the custom shell), plus the
# gaming profile.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;
  inherit (config.flake.lib) hypr;

  # Matched by EDID description (from `hyprctl monitors`), not connector, so
  # swapping DP cables does not reshuffle the layout.
  odyssey = "desc:Samsung Electric Company Odyssey G5 HK7X700060";
  dell = "desc:Dell Inc. Dell AW2518H #ASO0Wsxq3xLd";

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
          backups
          common
          networking
          users
          firmware
          bluetooth
          audio
          nvidia
          greetd
          openssh
          tailscale
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

        # ─── Secrets ───────────────────────────────────────────────────
        # Context7 API key. apps-claude-code finds it here and sends it from
        # its own MCP entry instead of the keyless plugin.
        age.secrets.docs-lookup-token = {
          file = "${inputs.secrets}/docs-lookup-token.age";
          owner = "brett";
          mode = "0400";
        };

        # ─── Boot ──────────────────────────────────────────────────────
        boot = {
          loader = {
            systemd-boot = {
              enable = true;
              # Windows has its own ESP on the P5 Plus, which systemd-boot can't
              # auto-detect, so this chain-loads it through the EDK2 shell. HD3b
              # is the shell's handle for that ESP (PARTUUID d5653750-…). Adding
              # or removing drives can change it: re-run `map -b` in the shell.
              windows.windows = {
                title = "Windows";
                efiDeviceHandle = "HD3b";
              };
              edk2-uefi-shell.enable = true;
            };
            efi.canTouchEfiVariables = true;
          };
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
        #
        # Then two NTFS partitions kept out of file managers (udisks'
        # UDISKS_IGNORE): Windows' on the P5 Plus and "Data" on the HGST disk.
        # Neither mounts from Thunar. Matched by filesystem UUID, as NVMe
        # numbering changes; `mount` still works on them.
        services.udev.extraRules = ''
          KERNEL=="card*", KERNELS=="${dgpu}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
          SUBSYSTEM=="block", ENV{ID_FS_UUID}=="10B00AA4B00A9100", ENV{UDISKS_IGNORE}="1"
          SUBSYSTEM=="block", ENV{ID_FS_UUID}=="E8400E89400E5F26", ENV{UDISKS_IGNORE}="1"
        '';

        # ─── Memory ────────────────────────────────────────────────────
        # Compressed swap in RAM (zstd, up to half of the 32 GB). No swap
        # partition, as the desktop never hibernates.
        zramSwap.enable = true;

        systemd = {
          # Let systemd-oomd kill a user cgroup that stays above 80% memory
          # pressure for 30s. Without it oomd monitors nothing, and on 31 Oct
          # a parallel CUDA build filled RAM and zram and froze the desktop.
          oomd.enableUserSlices = true;

          # oomd did not catch the 1 Nov freeze (a TRELLIS run thrashing RAM and
          # zram), and it kills whole cgroups, which here means every kitty tab.
          # This makes the kernel OOM-kill the single largest process once it
          # can no longer keep the last second of working set in RAM (MGLRU
          # thrashing prevention, docs.kernel.org/admin-guide/mm/multigen_lru.html).
          tmpfiles.rules = [ "w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000" ];
        };

        # ─── Game streaming ────────────────────────────────────────────
        # Sunshine, a host for Moonlight clients. A user service started
        # with the graphical session; pair at https://localhost:47990 on the
        # desktop itself.
        #
        # Reachable over Tailscale only, so a compromised LAN device cannot
        # reach the pairing service or the stream; clients add the desktop
        # by its tailnet name or 100.x address (no mDNS discovery there).
        # Setting `settings` makes the web UI read-only for configuration.
        #
        # Capture through Hyprland's wlr-screencopy, with no CAP_SYS_ADMIN:
        # through the NixOS wrapper the capability never reached the process
        # anyway, and the default probe also opened the portal's "Select
        # what to share" picker at every start. The nixpkgs build has no
        # CUDA, so nothing points it at the driver's libcuda; without
        # LD_LIBRARY_PATH NVENC fails and it falls back to software x264.
        # shortcut: NVENC copies frames GPU -> RAM -> GPU without CUDA; if
        # streams lag, try the package `.override { cudaSupport = true; }`
        # (a local build).
        services.sunshine = {
          enable = true;
          settings = {
            capture = "wlr";
            origin_web_ui_allowed = "pc";
            lan_encryption_mode = 2;
            wan_encryption_mode = 2;
          };
        };
        systemd.user.services.sunshine.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";
        # Sunshine's default ports (base 47989), less the web UI (47990).
        networking.firewall.interfaces.tailscale0 = {
          allowedTCPPorts = [
            47984
            47989
            48010
          ];
          allowedUDPPorts = [
            47998
            47999
            48000
            48002
            48010
          ];
        };

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
                desktop-display-doctor
                desktop-screenshots
                desktop-window-dissolve
                nvim
                apps-firefox
                apps-google-chrome
                apps-blender
                apps-git
                apps-ssh
                apps-cursor
                apps-spotify
                apps-godot
                apps-krita
                apps-fonts
                apps-worktrunk
                apps-fnm
                apps-claude-code
                apps-rea
                apps-comfyui
                apps-keymapp
                apps-nolvus
                apps-sims4
                profile-base
                profile-code
                profile-gaming
              ];
              home = {
                inherit username;
                homeDirectory = "/home/brett";
              };

              # The custom shell is the session's shell; Caelestia stays installed
              # until the migration is done (.scratch/custom-shell/issues/22).
              local.customShell.atLogin = true;

              # XDG profile path from the start: this home has no ~/.mozilla to
              # migrate (unlike the laptop, see docs/TODO.md), and
              # home.stateVersion "24.11" would otherwise keep the legacy path.
              programs.firefox.configPath = ".config/mozilla/firefox";

              # MangoHud lists the idle iGPU too; show only the 3080 Ti.
              programs.mangohud.settings.pci_dev = dgpu;

              # Render only on the 3080 Ti; the iGPU drives nothing. The
              # symlink comes from the udev rule above.
              wayland.windowManager.hyprland.settings = {
                env = [ (hypr.env "AQ_DRM_DEVICES" "/dev/dri/nvidia-dgpu") ];

                # Odyssey G5 on the left; Dell AW2518H on the right, turned 90°
                # clockwise (transform 1 rotates the picture back). The Odyssey
                # sits 240 px down to centre it on the 1920-tall Dell. The Dell's
                # EDID prefers 60 Hz, so 240 Hz has to be asked for.
                monitor = [
                  {
                    output = odyssey;
                    mode = "2560x1440@165";
                    position = "0x240";
                    scale = 1;
                  }
                  {
                    output = dell;
                    mode = "1920x1080@240";
                    position = "2560x0";
                    scale = 1;
                    transform = 1;
                  }
                ];

                # XWayland games (CS2 among them) size themselves to X's first
                # monitor, which is the rotated Dell unless a primary is set, so
                # make the Odyssey primary. XWayland drops the primary when the
                # KVM switches away and back, so redo it on every monitoradded
                # event. xrandr exits 0 for an output XWayland doesn't have yet,
                # so success is checked in its monitor list, with retries.
                on = [
                  (hypr.onStart (
                    lib.getExe (
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
                    )
                  ))
                ];

                # 1–5 on the Odyssey, 6–10 on the Dell. persistent keeps a
                # workspace alive while its monitor is off, so apps land on the
                # other screen rather than an invisible orphan.
                workspace_rule = map (ws: {
                  workspace = toString ws;
                  monitor = if ws <= 5 then odyssey else dell;
                  default = ws == 1 || ws == 6;
                  persistent = true;
                }) (lib.range 1 10);
              };
            };
        };
      }
    ];
  };
}
