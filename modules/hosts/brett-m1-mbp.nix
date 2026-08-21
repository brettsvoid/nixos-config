# Brett's M1 MacBook Pro (16 GB, aarch64-darwin).
{ config, inputs, ... }:
let
  username = config.flake.lib.username;
in
{
  flake.darwinConfigurations.brett-m1-mbp = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.darwinModules.home-manager
      (_: {
        imports = with config.flake.modules.darwin; [
          agenix
          common
          defaults
          users
          openssh
          homebrew
          tailscale
          timemachine
          nh-gc
          window-manager-aerospace
        ];

        # ─── Identity ──────────────────────────────────────────────────
        networking.hostName = "brett-m1-mbp";
        networking.computerName = "brett-m1-mbp";
        networking.localHostName = "brett-m1-mbp";

        nixpkgs.hostPlatform = "aarch64-darwin";

        # ─── Homebrew (host-only) ──────────────────────────────────────
        # Appended to the shared lists in modules/system/darwin/homebrew.nix
        # — these options are lists, so the effective Brewfile is shared ++
        # this. Everything here is on the MBP and not the mac mini: iOS/
        # Android build tooling, the work HashiCorp/Stripe/Auth0 CLIs, and
        # `borders`. The one exception is `sonobus`, declared on both hosts
        # because it is the two ends of one audio bridge (see the cask
        # comment below).
        # The mini dropped `borders` when it moved to the aerospace
        # stack; this host kept it, and its brew-installed launchd agent
        # (`homebrew.mxcl.borders`) is still running alongside AeroSpace.
        # Nothing here depends on it — it is a standing decision to revisit,
        # not a requirement.
        homebrew = {
          taps = [
            "anirudhg07/anirudhg07"
            "auth0/auth0-cli"
            "aws/tap"
            "facebook/fb"
            "felixkratz/formulae"
            "gabotechs/taps"
            "hashicorp/tap"
            "julien-cpsn/atac"
            "koekeishiya/formulae"
            "libsql/sqld"
            "stripe/stripe-cli"
            "tursodatabase/tap"
            "wix/brew"
          ];
          brews = [
            "anirudhg07/anirudhg07/cheatshh"
            "ansible"
            "auth0/auth0-cli/auth0"
            "docker"
            "facebook/fb/idb-companion"
            "felixkratz/formulae/borders"
            "gabotechs/taps/dep-tree"
            "gcc"
            "gdu"
            "git-cliff"
            "hashicorp/tap/nomad"
            "hashicorp/tap/terraform"
            "julien-cpsn/atac/atac"
            "lazyjournal"
            "lima"
            "llvm"
            "node"
            "postgresql@15"
            "pre-commit"
            "python@3.12"
            "qemu"
            "qrencode"
            "qt@5"
            "stripe/stripe-cli/stripe"
            "tlrc"
            "tursodatabase/tap/turso"
            "wireguard-tools"
            "wix/brew/applesimutils"
            "yt-dlp"
          ];
          casks = [
            "arduino-ide"
            # ─── Audio bridge to the mac mini ──────────────────────────
            # Video calls run on this machine (it has the webcam) while the
            # headset stays plugged into the KVM on the mini. SonoBus
            # carries audio both ways over the LAN, reading from and
            # writing to two virtual devices on this side:
            #
            #   call app  ──out──▶ BlackHole 16ch ──▶ SonoBus ──▶ mini
            #   call app ◀──mic─── BlackHole 2ch  ◀── SonoBus ◀── mini
            #
            # Two distinct devices are required: with one, SonoBus would
            # read back its own output and loop. The channel-count variants
            # ship as separate installers with distinct device UIDs, so
            # they coexist as independent devices without recompiling.
            # 2ch is deliberately the microphone side — call apps are
            # fussier about input devices than output devices, and a
            # 16-channel device offered as a mic invites misbehaviour.
            #
            # The mini needs no virtual devices at all; it already declares
            # `sonobus` and uses the real headset for both directions, so
            # nothing driver-level lands on the work machine.
            #
            # Both BlackHole casks are .pkg installers and need a reboot
            # before the devices appear.
            "blackhole-16ch"
            "blackhole-2ch"
            "godot"
            "mqtt-explorer"
            # This end of the audio bridge above; the mini declares its own.
            "sonobus"
            "vlc"
          ];
        };

        # ─── Home Manager wiring ───────────────────────────────────────
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = { inherit inputs; };
          users.${username} = {
            # `darwin-sketchybar` is imported for its config tree only — the
            # daemon is disabled (edgebar replaced it); the tree is kept as
            # the reference edgebar is ported from.
            imports = with config.flake.modules.homeManager; [
              base
              shell-zsh
              shell-aliases
              shell-env
              shell-functions
              shell-starship
              shell-tools
              terminals-tmux
              terminals-herdr
              terminals-ghostty
              terminals-kitty
              darwin-aerospace
              darwin-sketchybar
              darwin-edgebar
              darwin-wallpaper
              desktop-wallpapers
              darwin-karabiner
              nvim
              apps-git
              apps-ssh
              apps-fonts
              apps-sql-formatter
              apps-nh
              apps-comma
              apps-worktrunk
              apps-claude-code
              apps-sesh
              apps-tmuxinator
              apps-fnm
              profile-base
              profile-code
              profile-work
            ];

            # ─── Desktop look (per machine) ────────────────────────────
            # Seeded on the first switch that declares them and re-applied
            # only when these values change — `select-wallpaper` and
            # `select-scheme` picks survive later rebuilds.
            local.wallpaper.default = "chisato_petals_of_silence_4k.jpg";
            local.edgebar.scheme = "scheme-tonal-spot";

            # ─── Workspace assignment (this machine only) ──────────────
            # Captured from a live layout with:
            #   aerospace list-windows --all --json \
            #     --format '%{app-bundle-id}%{app-name}%{workspace}'
            #
            # Order matters — only the first matching rule runs. Tyto is a
            # Chrome PWA, so its bundle ID extends com.google.Chrome and must
            # come first.
            #
            # 8, 9 and 0 are force-assigned to the secondary display in
            # aerospace.toml.in, so SonoBus, Spotify and Obsidian follow the
            # external monitor when one is attached.
            local.aerospace.windowAssignments = [
              {
                appId = "com.google.Chrome.app.fiegnlgmbkhlmacibejnbdmickgdeojg"; # Tyto
                workspace = "3";
              }
              {
                appId = "net.kovidgoyal.kitty";
                workspace = "1";
              }
              {
                appId = "com.vivaldi.Vivaldi";
                workspace = "2";
              }
              {
                appId = "com.google.Chrome";
                workspace = "4";
              }
              {
                appId = "com.Sonosaurus.SonoBus";
                workspace = "8";
              }
              {
                appId = "com.spotify.client";
                workspace = "9";
              }
              {
                appId = "md.obsidian";
                workspace = "0";
              }
            ];

            home = {
              inherit username;
              homeDirectory = "/Users/brett";
            };
          };
        };
      })
    ];
  };
}
