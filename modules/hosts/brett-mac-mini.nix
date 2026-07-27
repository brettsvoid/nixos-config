# Brett's Mac mini (aarch64-darwin), driving two external displays
# (Odyssey G5 landscape + Dell AW2518H rotated portrait).
#
# Converted from the pre-nix chezmoi dotfiles — see the migration notes at
# the bottom of this file for the things that must happen by hand once, and
# for the config that intentionally did NOT carry over.
{ config, inputs, ... }:
let
  username = config.flake.lib.username;

  # ─── Window-manager stack swap ──────────────────────────────────────
  # Same switch as brett-m1-mbp.nix — see that file for the full rationale.
  # AeroSpace here too, so keybindings stay identical across both Macs.
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
  flake.darwinConfigurations.brett-mac-mini = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.darwinModules.home-manager
      (_: {
        imports =
          (with config.flake.modules.darwin; [
            agenix
            common
            defaults
            users
            openssh
            homebrew
            tailscale
            # Time Machine has no destination configured on this machine
            # either (`tmutil destinationinfo` → none), so the module's
            # rationale holds: disabling it stops backupd polling for a
            # destination that will never exist. Borg is the backup here.
            timemachine
            nh-gc
          ])
          ++ wm.system;

        # ─── Identity ──────────────────────────────────────────────────
        # Renames the machine from its factory `Bretts-Mac-mini-7`. The
        # rebuild aliases resolve the host config by hostname, so this must
        # match the attribute name above; the very first switch still needs
        # an explicit `#brett-mac-mini`.
        networking.hostName = "brett-mac-mini";
        networking.computerName = "brett-mac-mini";
        networking.localHostName = "brett-mac-mini";

        nixpkgs.hostPlatform = "aarch64-darwin";

        # ─── Homebrew (host-only) ──────────────────────────────────────
        # Appended to the shared lists in modules/system/darwin/homebrew.nix.
        # Snapshotted from this machine's `brew leaves --installed-on-request`
        # minus everything nixpkgs now provides (bat, fd, gh, lazygit, tmux,
        # neovim, fzf, zoxide, direnv, ripgrep, awscli, tailscale, …) — those
        # brew copies used to shadow the nix ones on PATH, so they are
        # deliberately dropped and `cleanup = "uninstall"` removes them.
        homebrew = {
          taps = [
            # Only for the `tabularis` cask below; every host-only formula
            # here comes from homebrew/core.
            "tabularisdb/tabularis"
          ];
          brews = [
            "ack"
            "aider"
            "bacon"
            "borgbackup"
            "cargo-llvm-cov"
            "cargo-nextest"
            "cargo-sweep"
            # Transitional: the old dotfile manager. Keep it installed until
            # the chezmoi source at ~/.local/share/chezmoi is fully retired,
            # so the pre-nix config stays readable/diffable during migration.
            "chezmoi"
            "cloudflared"
            "d2"
            "livekit"
            "redis"
            "sccache"
            "semgrep"
            "sqlc"
            "trivy"
            "trufflehog"
            "visidata"
            "watch"
            "worktrunk"
            "yarn"
          ];
          casks = [
            "codex"
            "cursor"
            "discord"
            "git-credential-manager"
            "github"
            "google-chrome"
            "grok-build"
            "keymapp"
            "kitty"
            "sonobus"
            # Installed as a cask here rather than importing the
            # `apps-spotify` home module — that module pulls pkgs.spotify,
            # which would be a second copy of the same app.
            "spotify"
            "tabularis"
            # NOTE: the stale `docker` and `syncthing` casks currently
            # installed here are the pre-rename aliases of `docker-desktop`
            # and `syncthing-app` (both in the shared list). They are
            # intentionally NOT declared, so activation uninstalls the
            # duplicates — same treatment homebrew.nix already gives
            # `zen-browser`.
          ];
        };

        # ─── Home Manager wiring ───────────────────────────────────────
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          # Existing chezmoi-applied dotfiles (~/.zshrc, ~/.gitconfig,
          # ~/.config/{nvim,tmux,ghostty,karabiner}) are moved aside to
          # *.backup on the first activation rather than causing a collision.
          backupFileExtension = "backup";
          extraSpecialArgs = { inherit inputs; };
          users.${username} = {
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
