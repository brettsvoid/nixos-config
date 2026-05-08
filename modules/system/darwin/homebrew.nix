# Declarative bridge over /opt/homebrew using nix-darwin's built-in
# `homebrew = { ... }` module. We don't use the separate `nix-homebrew`
# input — that adds flake-pinning of homebrew/{core,cask,bundle} taps
# but is fragile to layer on top of an existing /opt/homebrew install.
# The lists below run `brew bundle` at activation against an existing
# brew installation that nix doesn't manage.
#
# CRITICAL: onActivation.cleanup = "none" — do NOT zap brews/casks not
# declared here. Phase B is "track current state". Phase C audits and
# flips this to "zap".
_: {
  flake.modules.darwin.homebrew =
    { config, lib, ... }:
    {
      # ─── Workaround: brew bundle 5.1.x tap regression ─────────────
      # `brew bundle` 5.1.x pre-validates all formula names BEFORE
      # processing tap entries — meaning a Brewfile with `tap "foo/bar"`
      # followed by `brew "foo/bar/x"` errors on the brew lookup before
      # ever tapping. Pre-tap each declared tap as user brett before the
      # homebrew module's bundle phase runs.
      # Drop this when upstream brew bundle resolves taps before brews.
      system.activationScripts.preActivation.text = lib.mkAfter ''
        if [ -x /opt/homebrew/bin/brew ]; then
          existing_taps="$(sudo --user=brett /opt/homebrew/bin/brew tap 2>/dev/null || true)"
          for tap in ${
            lib.concatStringsSep " " (map (t: lib.escapeShellArg t.name) config.homebrew.taps)
          }; do
            if ! echo "$existing_taps" | grep -qx "$tap"; then
              echo >&2 "Pre-tapping $tap (brew bundle 5.1.x workaround)..."
              sudo --user=brett --set-home /opt/homebrew/bin/brew tap "$tap" || true
            fi
          done
        fi
      '';

      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = false;
          upgrade = false;
          # PHASE B: do not delete anything not in this list. Phase C flips
          # this to "zap" once the migration audit is complete.
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

        # Snapshot from `brew leaves --installed-on-request`. Many of these
        # have nixpkgs equivalents; Phase C audits which to migrate.
        brews = [
          "age"
          "angband"
          "anirudhg07/anirudhg07/cheatshh"
          "ansible"
          "auth0/auth0-cli/auth0"
          "awscli"
          "bat"
          "bore-cli"
          "bundletool"
          "caddy"
          "cmake"
          "cocoapods"
          "dive"
          "docker"
          "dua-cli"
          "duckdb"
          "duf"
          "dust"
          "entr"
          "facebook/fb/idb-companion"
          "fastlane"
          "fd"
          "felixkratz/formulae/borders"
          # sketchybar moved to nix-darwin services (see window-manager.nix)
          "ffmpegthumbnailer"
          "fnm"
          "gabotechs/taps/dep-tree"
          "gcc"
          "gdu"
          "gh"
          "git"
          "git-cliff"
          "git-delta"
          "git-gui"
          "git-lfs"
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
          # skhd + yabai moved to nix-darwin services (see window-manager.nix)
          "lazydocker"
          "lazygit"
          "lazyjournal"
          "libsixel"
          "lima"
          "llvm"
          "lsd"
          "luarocks"
          "mkcert"
          "ncdu"
          "neomutt"
          "neovim"
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
          "procs"
          "python@3.10"
          "python@3.11"
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
          "zoxide"
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
          "codex"
          "cursor"
          "dbeaver-community"
          "docker-desktop"
          "font-fira-code-nerd-font"
          "font-fira-mono-nerd-font"
          "font-symbols-only-nerd-font"
          "forklift"
          "ghostty"
          "godot"
          "hammerspoon"
          "iterm2"
          "karabiner-elements"
          "kitty"
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
          # vivaldi temporarily excluded: cask metadata's download URL 404s
          # (upstream issue; the locally installed app keeps working). Add
          # back when homebrew-cask publishes a new version.
          "vlc"
          "vnc-viewer"
          "wezterm"
          "zen"
        ];
      };
    };
}
