# Declarative bridge over /opt/homebrew using nix-darwin's built-in
# `homebrew = { ... }` module. We don't use the separate `nix-homebrew`
# input — that adds flake-pinning of homebrew/{core,cask,bundle} taps
# but is fragile to layer on top of an existing /opt/homebrew install.
# The lists below run `brew bundle` at activation against an existing
# brew installation that nix doesn't manage.
#
# `onActivation.cleanup = "none"` — undeclared brews/casks are left alone.
# Flipping to "uninstall"/"zap" is blocked on resolving the vivaldi cask
# (currently undeclared because its upstream cask URL 404s; the locally
# installed app keeps working). Once the cask is republishable, declare
# it and flip cleanup. Manual `brew uninstall` is the workflow until then.
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
      #
      # Also: a symlink from 2021 brew installs at
      # /opt/homebrew/share/zsh/site-functions/_brew points to a path
      # that no longer exists; modern brew reports "Completions are not
      # linked" and won't recreate it. The dangling link triggers a
      # compinit error in every new zsh session.
      system.activationScripts.preActivation.text = lib.mkAfter ''
        if [ -L /opt/homebrew/share/zsh/site-functions/_brew ] \
           && [ ! -e /opt/homebrew/share/zsh/site-functions/_brew ]; then
          rm -f /opt/homebrew/share/zsh/site-functions/_brew
        fi

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
          # sketchybar moved to nix-darwin services (see window-manager.nix)
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
          # skhd + yabai moved to nix-darwin services (see window-manager.nix)
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
          # neovim removed: the Nix-built `programs.neovim` (with its full
          # extraPackages LSP/formatter toolchain incl. nil) is the canonical
          # nvim now. The Homebrew build shadowed it on PATH and forced a
          # reliance on Mason for tooling.
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
          # kitty managed via home-manager (programs.kitty in
          # modules/home/terminals/kitty.nix). Removed from brew so the
          # two installs stop competing — the brew bundle would only
          # be picked up by LaunchServices, which is what made `open -a
          # Kitty` open the wrong copy.
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
