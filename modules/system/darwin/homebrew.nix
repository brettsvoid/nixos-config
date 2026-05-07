# nix-homebrew: declarative bridge over /opt/homebrew.
#
# CRITICAL FIRST-SWITCH BEHAVIOUR:
#   - autoMigrate = true adopts the existing /opt/homebrew install rather
#     than reinstalling.
#   - onActivation.cleanup = "none" — do NOT zap brews/casks not declared
#     here. Phase B is "track current state". Phase C is when we audit
#     what to migrate to nix and flip cleanup = "zap".
#
# The brews/casks/taps lists below mirror exactly what's installed today
# (snapshot from `brew leaves --installed-on-request` + `brew list --cask`
# + `brew tap` on 2026-05-07). After Phase B activates, future drift is
# silently allowed; Phase C tightens this.
{ inputs, ... }:
{
  flake.modules.darwin.homebrew = _: {
    nix-homebrew = {
      enable = true;
      enableRosetta = false;
      user = "brett";
      autoMigrate = true;
      taps = {
        "homebrew/homebrew-core" = inputs.homebrew-core;
        "homebrew/homebrew-cask" = inputs.homebrew-cask;
        "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
      };
      mutableTaps = false;
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = false;
        # PHASE B: do not delete anything not in this list. Phase C flips
        # this to "zap" once the migration audit is complete.
        cleanup = "none";
      };

      # Third-party taps (homebrew/{core,cask,bundle} are pinned via
      # nix-homebrew.taps above so they get flake-locked instead).
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
        "chezmoi"
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
        "felixkratz/formulae/sketchybar"
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
        "koekeishiya/formulae/skhd"
        "koekeishiya/formulae/yabai"
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

      # Snapshot from `brew list --cask`.
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
        "syncthing"
        "syncthing-app"
        "vivaldi"
        "vlc"
        "vnc-viewer"
        "wezterm"
        "zen"
        "zen-browser"
      ];
    };
  };
}
