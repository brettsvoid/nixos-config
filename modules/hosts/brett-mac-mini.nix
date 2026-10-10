# Brett's Mac mini (aarch64-darwin), driving two external displays
# (Odyssey G5 landscape + Dell AW2518H rotated portrait).
{ config, inputs, ... }:
let
  username = config.flake.lib.username;
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
        imports = with config.flake.modules.darwin; [
          agenix
          common
          defaults
          users
          openssh
          homebrew
          tailscale
          # No Time Machine destination here either; Borg is the backup.
          timemachine
          nh-gc
          window-manager-aerospace
        ];

        # ─── Identity ──────────────────────────────────────────────────
        # Must match the flake attribute: the rebuild aliases pick the config
        # by hostname. The first switch needs an explicit `#brett-mac-mini`.
        networking.hostName = "brett-mac-mini";
        networking.computerName = "brett-mac-mini";
        networking.localHostName = "brett-mac-mini";

        nixpkgs.hostPlatform = "aarch64-darwin";

        # ─── Homebrew (host-only) ──────────────────────────────────────
        # Appended to the shared lists in modules/system/darwin/homebrew.nix.
        # Leave out brew copies of anything nix provides (bat, fd, gh, fzf,
        # neovim, tmux, …): they would shadow the nix ones on PATH.
        homebrew = {
          taps = [
            # For the `tabularis` cask below.
            "tabularisdb/tabularis"

            # felixkratz/formulae and hashicorp/tap back the tap-qualified
            # brews below. The rest have no formulae declared but stay: only
            # declared taps are trusted (see homebrew.nix), and `brew bundle`
            # won't remove a formula from an untrusted tap. They can go once
            # a switch has uninstalled their formulae.
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
            # ── Tap-qualified formulae (the next four) ────────────────
            # Not in homebrew/core. consul, nomad and packer are in nixpkgs.
            # Deliberately absent: terraform (profile-work installs it), and
            # cheatshh, whose brew dependencies (fzf, jq) would shadow the
            # nix ones on PATH.
            "felixkratz/formulae/svim"
            "hashicorp/tap/consul"
            "hashicorp/tap/nomad" # NOMAD_ADDR/_TOKEN in ~/.config/zsh/local.zsh
            "hashicorp/tap/packer"
            "redis"
            "sccache"
            "semgrep"
            "sqlc"
            "trivy"
            "trufflehog"
            "visidata"
            "watch"
            # No worktrunk: it comes from nixpkgs (home/apps/worktrunk.nix),
            # and a brew copy's /opt/homebrew/bin/wt would shadow it on PATH.
            "yarn"
          ];
          casks = [
            "discord"
            "git-credential-manager"
            "github"
            "google-chrome"
            "grok-build"
            "keymapp"
            # No kitty cask: nixpkgs' kitty (terminals-kitty) includes
            # kitty.app, in ~/Applications/Home Manager Apps. The cask also
            # broke activation: brew's code is pinned (nix-homebrew's brew-src
            # input) but cask definitions come from Homebrew's live API, and
            # kitty's gained a `command_wrapper` artifact the pinned brew
            # lacks. Any declared cask can do that.
            "sonobus"
            # A cask rather than the apps-spotify home module, which would
            # install a second copy from nixpkgs.
            "spotify"
            "tabularis"
            # `docker` and `syncthing` are the old names of `docker-desktop`
            # and `syncthing-app` (shared list); don't declare them.
          ];
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
              darwin-hammerspoon
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
              apps-fnm
              apps-lspmux
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

            # This end sends the PRO X headset's mic, which is mono; stereo
            # would only duplicate the channel at double the bitrate.
            local.sonobus.sendChannels = "mono";

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
