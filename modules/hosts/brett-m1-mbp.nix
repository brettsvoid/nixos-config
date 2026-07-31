# Brett's M1 MacBook Pro (16 GB, aarch64-darwin).
{ config, inputs, ... }:
let
  username = config.flake.lib.username;

  # ─── Window-manager stack swap ──────────────────────────────────────
  # One switch drives BOTH halves of the WM stack — the system-side
  # launchd agents and the home-manager config — so the two can't drift
  # out of sync. Set to "yabai" or "aerospace"; files for both stacks
  # live side-by-side, so switching is a one-word edit — no deletes.
  wmStack = "aerospace";
  wm =
    {
      yabai = {
        system = with config.flake.modules.darwin; [ window-manager ];
        home = with config.flake.modules.homeManager; [
          darwin-yabai
          darwin-skhd
        ];
      };
      aerospace = {
        system = with config.flake.modules.darwin; [ window-manager-aerospace ];
        home = with config.flake.modules.homeManager; [ darwin-aerospace ];
      };
    }
    .${wmStack};
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
        # WM stack (system half) is appended below via `wm.system`; the
        # `wmStack` switch at the top of this file selects it.
        imports =
          (with config.flake.modules.darwin; [
            agenix
            common
            defaults
            users
            openssh
            homebrew
            tailscale
            timemachine
            nh-gc
          ])
          ++ wm.system;

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
        # `borders`. The mini dropped `borders` when it moved to the aerospace
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
            "godot"
            "mqtt-explorer"
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
            # WM stack (home half) is appended below via `wm.home`; the
            # `wmStack` switch at the top of this file selects it.
            # `darwin-sketchybar` stays enabled for either stack.
            imports =
              (with config.flake.modules.homeManager; [
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
                profile-base
                profile-code
                profile-work
              ])
              ++ wm.home;
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
