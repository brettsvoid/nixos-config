# Homebrew, fully managed by nix via two cooperating layers:
#   * nix-homebrew installs and owns /opt/homebrew itself, so a fresh Mac
#     bootstraps Homebrew from `darwin-rebuild switch` alone — no separate
#     install step. brew lives in the nix store, but while nix-homebrew is
#     active that path is part of the system closure (a GC root), so it
#     can't be garbage-collected out from under us. (Abandoning it is what
#     orphaned the old store path and broke brew — hence the re-adoption.)
#   * nix-darwin's built-in `homebrew = { ... }` module runs `brew bundle`
#     at activation to install the taps/brews/casks declared below.
# mutableTaps stays at its default (true), so the third-party taps below
# are added imperatively by brew and don't each need to be a flake input.
#
# `onActivation.cleanup = "none"` — undeclared brews/casks are left alone.
# Flipping to "uninstall"/"zap" is blocked on resolving the vivaldi cask
# (currently undeclared because its upstream cask URL 404s; the locally
# installed app keeps working). Once the cask is republishable, declare
# it and flip cleanup. Manual `brew uninstall` is the workflow until then.
_: {
  flake.modules.darwin.homebrew =
    { config, lib, inputs, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      # nix-homebrew installs and owns Homebrew, so `switch` bootstraps it
      # on a fresh machine. autoMigrate lets it adopt a pre-existing
      # /opt/homebrew (keeping installed packages) rather than erroring.
      nix-homebrew = {
        enable = true;
        user = "brett";
        autoMigrate = true;
      };

      # ─── Trust non-official taps before `brew bundle` ─────────────
      # brew 6.x refuses to load formulae/casks from non-official taps
      # unless they're trusted (HOMEBREW_REQUIRE_TAP_TRUST defaults to
      # true; the opt-out is deprecated). Trust exactly the taps declared
      # below — `brew trust` persists to trust.json, is idempotent, and
      # doesn't need the tap tapped first (bundle taps them itself). Run as
      # user brett so trust.json lands in brett's config, not root's.
      #
      # mkOrder 600 places this in the `homebrew` activation script after
      # nix-homebrew's prefix setup (mkBefore, 500) installs brew, but
      # before nix-darwin's bundle (default, 1000). On a fresh Mac brew
      # doesn't exist until this same activation, so no earlier phase could
      # do it.
      system.activationScripts.homebrew.text = lib.mkOrder 600 ''
        if [ -x /opt/homebrew/bin/brew ]; then
          for tap in ${
            lib.concatStringsSep " " (map (t: lib.escapeShellArg t.name) config.homebrew.taps)
          }; do
            sudo --user=brett --set-home /opt/homebrew/bin/brew trust --tap "$tap" || true
          done
        fi
      '';

      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = false;
          upgrade = false;
          # See top-of-file note. Holding at "none" until vivaldi can
          # rejoin the declared casks list.
          cleanup = "none";
        };

        # Third-party taps. homebrew/{core,cask,bundle} are auto-tapped by
        # brew on first use and don't need to be declared here.
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

        # `brew leaves --installed-on-request`. Anything migratable to
        # nixpkgs without losing platform-specific behaviour should move
        # over time; the remainder lives here. Items intentionally absent
        # because nix manages them (and the brew copy is redundant):
        # `direnv` (programs.direnv in profile-code), `yabai`/`skhd`/
        # `sketchybar` (services in system/darwin/window-manager.nix);
        # `gh`/`lazygit`/`git-delta`(→delta)/`git-lfs` (profile-code),
        # `bat`/`fd`/`dust`/`duf`/`procs`/`zoxide` (shell-tools),
        # `awscli`(→awscli2) (profile-work). The brew copies shadowed the
        # nix ones on PATH; removed here + `brew uninstall`d (cleanup=none).
        brews = [
          "age"
          "angband"
          "anirudhg07/anirudhg07/cheatshh"
          "ansible"
          "auth0/auth0-cli/auth0"
          "bore-cli"
          "bundletool"
          "caddy"
          "cmake"
          "cocoapods"
          "dive"
          "docker"
          "dua-cli"
          "duckdb"
          "entr"
          "facebook/fb/idb-companion"
          "fastlane"
          "felixkratz/formulae/borders"
          "ffmpegthumbnailer"
          "fnm"
          "gabotechs/taps/dep-tree"
          "gcc"
          "gdu"
          "git"
          "git-cliff"
          "git-gui"
          "gitleaks"
          "glow"
          "go"
          "graphviz"
          "hashicorp/tap/nomad"
          "hashicorp/tap/terraform"
          "humanlog"
          "imagemagick"
          "inframap"
          "ios-deploy"
          "julien-cpsn/atac/atac"
          "lazydocker"
          "lazyjournal"
          "libsixel"
          "lima"
          "llvm"
          "lsd"
          "luarocks"
          "mkcert"
          "ncdu"
          "neomutt"
          "nethack"
          "nmap"
          "node"
          "nushell"
          "openjdk@17"
          "pandoc"
          "parallel"
          "pastel"
          "pgcli"
          "pipx"
          "pkgconf"
          "pngpaste"
          "pnpm"
          "poppler"
          "portal"
          "postgresql@15"
          "posting"
          "pre-commit"
          "python@3.10"
          "python@3.11"
          "python@3.12"
          "qemu"
          "qrencode"
          "qt@5"
          "rogue"
          "rustup"
          "sesh"
          "sevenzip"
          "sshs"
          "stripe/stripe-cli/stripe"
          "taskwarrior-tui"
          "terragrunt"
          "tflint"
          "tfsec"
          "timewarrior"
          "tlrc"
          "tmuxinator"
          "tree-sitter-cli"
          "tursodatabase/tap/turso"
          "uv"
          "w3m"
          "watchman"
          "wget"
          "wireguard-tools"
          "wireshark"
          "wix/brew/applesimutils"
          "yazi"
          "yt-dlp"
          "zsh-autosuggestions"
          "zsh-syntax-highlighting"
        ];

        # Snapshot from `brew list --cask`. `syncthing` (moved to formula) and
        # `zen-browser` (renamed to `zen`) are stale local-only entries —
        # excluded here so brew bundle doesn't fail on them.
        casks = [
          "amethyst"
          "anaconda"
          "arduino-ide"
          "bitwarden"
          "burp-suite"
          "dbeaver-community"
          "docker-desktop"
          "font-fira-code-nerd-font"
          "font-fira-mono-nerd-font"
          "font-symbols-only-nerd-font"
          "ghostty"
          "godot"
          "hammerspoon"
          "karabiner-elements"
          "loopback"
          "macdown"
          "mos"
          "mqtt-explorer"
          "ngrok"
          "postman"
          "raspberry-pi-imager"
          "raycast"
          "shortcat"
          "syncthing-app"
          "vlc"
          "vnc-viewer"
          "wezterm"
          "zen"
        ];
      };
    };
}
