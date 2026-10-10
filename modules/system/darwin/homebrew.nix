# Homebrew, managed by nix in two layers:
#   * nix-homebrew installs and owns /opt/homebrew, so a fresh Mac gets
#     Homebrew from `darwin-rebuild switch` alone. Its brew lives in the nix
#     store but is part of the system closure, so GC can't remove it.
#   * nix-darwin's `homebrew` module runs `brew bundle` at activation for
#     the taps/brews/casks below. mutableTaps stays true, so taps are added
#     by brew and need not be flake inputs.
#
# ─── nixpkgs first; Homebrew is the fallback ────────────────────────────
# Add a package here only when nixpkgs has no working darwin build. Check
# the repo's pinned nixpkgs (not `nixpkgs#...`, the floating registry):
#
#   nix eval .#darwinConfigurations.brett-m1-mbp.pkgs.<pkg>.meta.platforms
#   nix build --dry-run .#darwinConfigurations.brett-m1-mbp.pkgs.<pkg>
#
# The first must list aarch64-darwin; the second must say "will be fetched",
# not "will be built" (it prints nothing if the closure is already local).
# If both pass, write a modules/home/apps/<name>.nix module instead, as
# modules/home/apps/blender.nix does: home-manager's linkApps (on at this
# home.stateVersion) puts its .app in ~/Applications/Home Manager Apps.
# Besides pinning, a cask can gain an artifact type the pinned brew does not
# implement, and a failing `brew bundle` aborts the whole switch (the kitty
# cask did this on the mini; see modules/hosts/brett-mac-mini.nix).
#
# The lists below predate this rule and have not been audited against it.
#
# ─── Shared vs. per-host ────────────────────────────────────────────────
# The lists below are installed on every Mac. Host-only packages go in the
# host file (modules/hosts/*.nix); the list options concatenate, so each
# Mac's Brewfile is this plus its host's extras. cleanup = "uninstall"
# removes anything in neither, so before adding a host, check its
# `brew leaves --installed-on-request` and keep what's worth keeping.
_: {
  flake.modules.darwin.homebrew =
    {
      config,
      lib,
      inputs,
      flake,
      ...
    }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      # autoMigrate adopts an existing /opt/homebrew, keeping its packages,
      # rather than erroring.
      nix-homebrew = {
        enable = true;
        user = flake.lib.username;
        autoMigrate = true;
        # Set in the `brew` launcher, so it covers every brew call,
        # activation included.
        extraEnv.HOMEBREW_NO_ANALYTICS = "1";
      };

      # Three steps ordered around nix-darwin's bundle (default priority,
      # 1000). They run as brett so trust.json and the cache stay his.
      system.activationScripts.homebrew.text = lib.mkMerge [
        # ─── Trust non-official taps before `brew bundle` ───────────
        # brew 6.x won't load formulae/casks from non-official taps unless
        # they are trusted (HOMEBREW_REQUIRE_TAP_TRUST defaults to true).
        # `brew trust` is idempotent and doesn't need the taps tapped yet.
        # mkOrder 600: after nix-homebrew installs brew (mkBefore, 500),
        # before the bundle.
        (lib.mkOrder 600 ''
          if [ -x /opt/homebrew/bin/brew ]; then
            sudo --user=${flake.lib.username} --set-home /opt/homebrew/bin/brew trust --tap ${
              lib.concatStringsSep " " (map (t: lib.escapeShellArg t.name) config.homebrew.taps)
            } || true
          fi
        '')
        # ─── Upgrade the casks marked `greedy` ──────────────────────
        # Not onActivation.upgrade: that would also re-run the .pkg casks
        # (sonobus, blackhole-*), whose installers macOS App Management
        # blocks from modifying an existing app, failing the whole switch.
        # `--greedy` is needed because brew never reports `auto_updates`
        # casks as outdated without it. mkOrder 1400: after the bundle,
        # before `brew cleanup` (mkAfter, 1500). `|| true` so a failed
        # upgrade can't fail the switch.
        (lib.mkOrder 1400 (
          let
            greedy = map (c: c.name) (lib.filter (c: c.greedy == true) config.homebrew.casks);
          in
          lib.optionalString (greedy != [ ]) ''
            if [ -x /opt/homebrew/bin/brew ]; then
              echo >&2 "Homebrew greedy cask upgrade..."
              sudo --user=${flake.lib.username} --set-home /opt/homebrew/bin/brew upgrade --cask --greedy ${lib.concatStringsSep " " (map lib.escapeShellArg greedy)} || true
            fi
          ''
        ))
        # ─── Prune caches/logs after `brew bundle` ──────────────────
        # The bundle's cleanup uninstalls undeclared packages but doesn't
        # reclaim cache space, and it never runs a full `brew cleanup`.
        (lib.mkAfter ''
          if [ -x /opt/homebrew/bin/brew ]; then
            sudo --user=${flake.lib.username} --set-home /opt/homebrew/bin/brew cleanup || true
          fi
        '')
      ];

      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = false;
          upgrade = false;
          # Uninstall anything not declared. "uninstall", not "zap", keeps
          # cask user data and preferences.
          cleanup = "uninstall";
          # Redundant at the pinned nix-darwin, which already passes
          # --force-cleanup for cleanup = "uninstall".
          extraFlags = [ "--force-cleanup" ];
        };

        # No shared formula comes from a third-party tap, so taps live in
        # the host files. homebrew/{core,cask,bundle} need no declaring.
        taps = [ ];

        # Deliberately absent because nix installs them, and brew copies
        # would shadow them on PATH: direnv, lazygit, git-delta, git-lfs
        # (profile-code), gh (apps-git), bat, fd, dust, duf, procs, zoxide
        # (shell-tools), awscli (profile-work) and aerospace
        # (window-manager-aerospace.nix).
        brews = [
          "age"
          "angband"
          "bore-cli"
          "bundletool"
          "caddy"
          "cmake"
          "cocoapods"
          "dive"
          "dua-cli"
          "duckdb"
          "entr"
          "fastlane"
          "ffmpegthumbnailer"
          "fnm"
          "git"
          "git-gui"
          "gitleaks"
          "glow"
          "go"
          "graphviz"
          "humanlog"
          "imagemagick"
          "inframap"
          "ios-deploy"
          "lazydocker"
          "libsixel"
          "lsd"
          "luarocks"
          "mkcert"
          "ncdu"
          "neomutt"
          "nethack"
          "nmap"
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
          "posting"
          "python@3.10"
          "python@3.11"
          "rogue"
          "rustup"
          "sevenzip"
          "sshs"
          "taskwarrior-tui"
          # netwatch's alerts use it (/opt/homebrew/bin/terminal-notifier).
          # Homebrew rather than nixpkgs because macOS ties notification
          # permission to the delivering bundle, and both Macs have granted
          # it to this copy.
          "terminal-notifier"
          "terragrunt"
          "tflint"
          "tfsec"
          "timewarrior"
          "tree-sitter-cli"
          "uv"
          "w3m"
          "watchman"
          "wget"
          "wireshark"
          "yazi"
          "zsh-autosuggestions"
          "zsh-syntax-highlighting"
        ];

        # Not `syncthing` or `zen-browser`: Homebrew renamed those casks to
        # `syncthing-app` and `zen`.
        casks = [
          "amethyst"
          "bitwarden"
          "burp-suite"
          "dbeaver-community"
          "docker-desktop"
          "font-fira-code-nerd-font"
          "font-fira-mono-nerd-font"
          "font-symbols-only-nerd-font"
          "ghostty"
          "hammerspoon"
          # greedy: an `auto_updates` cask, which brew only upgrades greedily
          # (see the greedy-upgrade step above).
          {
            name = "karabiner-elements";
            greedy = true;
          }
          "loopback"
          "macdown"
          "mos"
          "ngrok"
          "postman"
          "raspberry-pi-imager"
          "raycast"
          "shortcat"
          "syncthing-app"
          "vivaldi"
          "vnc-viewer"
          "wezterm"
          "zen"
        ];
      };
    };
}
