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
# `onActivation.cleanup = "uninstall"` — the brews/casks lists are
# authoritative: anything installed but not declared here is uninstalled on
# activation (cask user-data is preserved; "zap" would also wipe that).
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
        # Baked into the `brew` launcher, so it applies to every brew call
        # including the activation bundle — not just interactive shells.
        extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      };

      # Two ordered steps wrapped around nix-darwin's bundle (default,
      # 1000), so this single attribute needs mkMerge. Both run as user
      # brett so trust.json / the cache dir are brett's, not root's.
      system.activationScripts.homebrew.text = lib.mkMerge [
        # ─── Trust non-official taps before `brew bundle` ───────────
        # brew 6.x refuses to load formulae/casks from non-official taps
        # unless trusted (HOMEBREW_REQUIRE_TAP_TRUST defaults to true; the
        # opt-out is deprecated). Trust exactly the declared taps — `brew
        # trust` persists to trust.json, is idempotent, accepts many taps
        # at once, and doesn't need them tapped first (bundle taps them).
        # mkOrder 600: after nix-homebrew's prefix setup (mkBefore, 500)
        # installs brew, before the bundle. On a fresh Mac brew doesn't
        # exist until this activation, so no earlier phase could do it.
        (lib.mkOrder 600 ''
          if [ -x /opt/homebrew/bin/brew ]; then
            sudo --user=brett --set-home /opt/homebrew/bin/brew trust --tap ${
              lib.concatStringsSep " " (map (t: lib.escapeShellArg t.name) config.homebrew.taps)
            } || true
          fi
        '')
        # ─── Prune caches/logs after `brew bundle` ──────────────────
        # --force-cleanup uninstalls undeclared *packages* but doesn't
        # reclaim cache disk space, and the bundle never runs a full
        # `brew cleanup`. mkAfter (1500) runs this after the bundle.
        (lib.mkAfter ''
          if [ -x /opt/homebrew/bin/brew ]; then
            sudo --user=brett --set-home /opt/homebrew/bin/brew cleanup || true
          fi
        '')
      ];

      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = false;
          upgrade = false;
          # Authoritative: any formula/cask installed but not declared here
          # is uninstalled on activation. "uninstall" (not "zap") so cask
          # user-data/preferences are preserved.
          cleanup = "uninstall";
          # nix-darwin emits `brew bundle ... --cleanup`, which in brew 6.x
          # only *asks* to clean up (it requires --force/--force-cleanup/
          # $HOMEBREW_ASK). --force-cleanup makes activation unattended; it's
          # narrower than --force, which would also overwrite installs.
          extraFlags = [ "--force-cleanup" ];
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
          "vivaldi"
          "vlc"
          "vnc-viewer"
          "wezterm"
          "zen"
        ];
      };
    };
}
