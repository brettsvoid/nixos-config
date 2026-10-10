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

        # ─── SSH ───────────────────────────────────────────────────────
        # Merged with the shared list in system/authorized-keys.nix.
        users.users.${username}.openssh.authorizedKeys.keys = [
          # brett-desktop (~/.ssh/id_ed25519)
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBRdwvFu0KB0CGdRob802A+tgZYQm8i8f6UG31sXdFuR brett@brett-desktop"
        ];

        # ─── Homebrew (host-only) ──────────────────────────────────────
        # Appended to the shared lists in modules/system/darwin/homebrew.nix.
        # `borders` is optional: nothing in the repo depends on it.
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
            # Calls run here (it has the webcam); the headset is on the mini.
            # SonoBus carries audio both ways over the LAN via two virtual
            # devices on this side:
            #
            #   call app  ──out──▶ BlackHole 16ch ──▶ SonoBus ──▶ mini
            #   call app ◀──mic─── BlackHole 2ch  ◀── SonoBus ◀── mini
            #
            # Two devices, or SonoBus reads back its own output and loops.
            # 2ch is the mic side because call apps are fussier about input
            # devices. The mini uses the real headset and needs neither. Both
            # casks are .pkg installers and need a reboot before the devices
            # appear.
            "blackhole-16ch"
            "blackhole-2ch"
            "mqtt-explorer"
            # This end of the audio bridge above.
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
            # darwin-sketchybar only links its config tree, kept as the
            # reference edgebar is ported from; the daemon does not run.
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
              darwin-sonobus
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
              apps-obsidian
              apps-blender
              apps-godot
              apps-netwatch
              profile-base
              profile-code
              profile-work
            ];

            # ─── Desktop look (per machine) ────────────────────────────
            # Applied when first declared and again only when changed, so
            # `select-wallpaper` and `select-scheme` picks survive rebuilds.
            local.wallpaper.default = "chisato_petals_of_silence_4k.jpg";
            local.edgebar.scheme = "scheme-tonal-spot";

            # This end sends programme audio for the headset, not a mic.
            local.sonobus.sendChannels = "stereo";

            # ─── Workspace assignment (this machine only) ──────────────
            # appId must match the bundle ID exactly; Tyto, a Chrome PWA, has
            # its own. 8, 9 and 0 are force-assigned to the secondary display
            # in aerospace.toml.in, so SonoBus, Spotify and Obsidian follow
            # the external monitor when one is attached.
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
