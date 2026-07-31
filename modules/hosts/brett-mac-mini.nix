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
            # Swaps left ⌘/⌥ for Universal Control, and supersedes the
            # hand-rolled com.local.KeyRemapping login agent.
            keyboard
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
            # For the `tabularis` cask below.
            "tabularisdb/tabularis"

            # Taps backing the tap-qualified formulae in `brews` below.
            #
            # Declaring a tap is what makes its formulae ACTIONABLE, not just
            # available: activation runs `brew trust --tap` over exactly this
            # list (see modules/system/darwin/homebrew.nix), and `brew bundle`
            # refuses to touch a formula from an untrusted tap — it skips it
            # with "tap formula is not trusted". So an undeclared tap means
            # its formulae are neither installed nor removed, just orphaned:
            # left on disk, cut off from their source, unupgradable.
            #
            # That is why the seven taps below whose formulae are all being
            # dropped still appear here. Undeclaring them would not remove
            # anything, it would strand it. Once the first switch has run
            # they serve no purpose and can go: anirudhg07/anirudhg07,
            # auth0/auth0-cli, gabotechs/taps, julien-cpsn/atac,
            # localstack/tap, stripe/stripe-cli, wix-incubator/brew.
            #
            # aws/tap and asmvik/formulae are absent on purpose — nothing
            # from either is installed, so untapping them is correct.
            "anirudhg07/anirudhg07"
            "auth0/auth0-cli"
            "felixkratz/formulae"
            "gabotechs/taps"
            "hashicorp/tap"
            "julien-cpsn/atac"
            "localstack/tap"
            "stripe/stripe-cli"
            "wix-incubator/brew"
          ];
          brews = [
            "ack"
            "aider"
            "bacon"
            "borgbackup"
            "cargo-llvm-cov"
            "cargo-nextest"
            "cargo-sweep"
            "cloudflared"
            "d2"
            "livekit"
            # ── Tap-qualified formulae ────────────────────────────────
            # None of these are in homebrew/core or nixpkgs, so declaring
            # them here is the only thing keeping them installed. Kept
            # because they are actually used; the count is uses found in
            # ~/.zsh_history.
            #
            # NOT kept, and uninstalled on the first switch:
            #   terraform (23)  — nixpkgs provides it via profile-work, so
            #                     the brew copy is the redundant one
            #   sketchybar (6)  — daemon is disabled under the aerospace
            #   borders (7)       stack (edgebar replaced it); on the yabai
            #                     stack nixpkgs supplies both
            #   auth0, stripe, atac, dep-tree, applesimutils (0 uses)
            #   localstack-cli  — no longer used
            #   cheatshh (2)    — not worth its dependency tail: it drags in
            #                     fzf, jq, yq, oniguruma, openssl@3, sqlite,
            #                     readline, xz, mpdecimal, ca-certificates and
            #                     a whole python@3.13. fzf and jq are also
            #                     provided by nixpkgs, and since `brew
            #                     shellenv` prepends /opt/homebrew/bin the brew
            #                     copies would shadow them.
            "felixkratz/formulae/svim" # 4
            "hashicorp/tap/consul" # 7
            "hashicorp/tap/nomad" # NOMAD_ADDR/_TOKEN in ~/.config/zsh/local.zsh
            "hashicorp/tap/packer" # 2
            "redis"
            "sccache"
            "semgrep"
            "sqlc"
            "trivy"
            "trufflehog"
            "visidata"
            "watch"
            # worktrunk moved to nixpkgs — see modules/home/apps/worktrunk.nix.
            # The brew copy here was 0.51.0 against 0.68.0 in nixpkgs after the
            # lock update, and it must go: leaving it installed would put
            # /opt/homebrew/bin/wt ahead of the nix profile on PATH for anything
            # not using WORKTRUNK_BIN. Activation uninstalls it.
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
            # kitty is NOT a cask here — nixpkgs ships the same version
            # (0.48.1) including kitty.app, and terminals-kitty already
            # configures it, so the cask was a second copy of one app. The
            # nix build lands in ~/Applications/Home Manager Apps/ rather
            # than /Applications/.
            #
            # It also broke activation. nix-homebrew pins the brew CODE (the
            # brew-src input, 2026-07-20) while cask DEFINITIONS come from
            # Homebrew's live JSON API. The kitty cask started declaring a
            # `command_wrapper` artifact that the pinned brew does not
            # implement, so `brew bundle` aborted with "undefined method
            # 'command_wrapper' for Cask 'kitty'". Removing the duplicate
            # fixes the symptom; the underlying skew is filed separately —
            # any declared cask can gain a new artifact type at any time.
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
                apps-worktrunk
                apps-claude-code
                apps-sesh
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
