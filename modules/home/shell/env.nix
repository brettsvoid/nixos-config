# Environment variables and PATH additions, mostly Mac-specific. Linux
# hosts get their PATH from system-side profiles, not from a per-user
# initExtra block.
#
# Secrets and machine-specific config are NOT kept here (this repo is
# public). Machine-local config is sourced at shell init from an
# untracked ~/.config/zsh/local.zsh (see local.zsh.example). Plaintext
# env-var secrets (BWS_ACCESS_TOKEN + a few API keys) live in an
# untracked ~/.env_vars, sourced via .zshenv below.
_: {
  flake.modules.homeManager.shell-env =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home.sessionVariables = {
        REACT_EDITOR = "nvim";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        ANDROID_HOME = "$HOME/Library/Android/sdk";
        PNPM_HOME = "$HOME/Library/pnpm";
        CONDA_BASE = "/opt/homebrew/anaconda3";
      };

      # Secrets bootstrap. ~/.env_vars is an untracked, plaintext file
      # exporting BWS_ACCESS_TOKEN + a few API keys.
      #
      # This is NOT staged for an agenix migration. Work secrets stay in
      # Bitwarden Secrets Manager deliberately: local.zsh holds only
      # lookup IDs, so rotating a key means editing it in the Bitwarden UI
      # with no repo change, no re-encrypt and no rebuild. agenix earns
      # its place for host-level secrets (see docs/SECRETS.md), which is a
      # separate concern from these per-user shell env vars.
      #
      # ~/.env_vars MUST be sourced from .zshenv (this option), not
      # .zshrc: .zshenv runs before .zshrc, so local.zsh sees
      # BWS_ACCESS_TOKEN at the moment it is sourced. That timing still
      # matters even though the secret fetches are now lazy — local.zsh
      # guards on BWS_ACCESS_TOKEN before installing its preexec hook, so
      # an unset value there means the hook never registers and no secret
      # ever loads. Sourcing it later (or not at all, as the nix migration
      # accidentally did) makes the whole block silently no-op. The [ -f ]
      # guard keeps this harmless on hosts without the file. Keep the file
      # mode 600.
      programs.zsh.envExtra = ''
        [ -f "$HOME/.env_vars" ] && source "$HOME/.env_vars"
      '';

      # Put Homebrew on PATH. Nothing else does, on either host:
      # /etc/paths, /etc/paths.d, macOS's /etc/zprofile (which only runs
      # path_helper over those) and nix-darwin's environment.systemPath all
      # omit /opt/homebrew/bin.
      #
      # This has to be an ABSOLUTE path. nix-darwin's generated /etc/zshrc
      # already runs `eval "$(brew shellenv 2>/dev/null || true)"`, but by
      # bare name — and zsh reads /etc/zshenv, ~/.zshenv, /etc/zprofile,
      # ~/.zprofile, then /etc/zshrc, so nothing has put brew on PATH by the
      # time it runs. The lookup fails and `|| true` hides it.
      #
      # profileExtra, not initContent: `brew shellenv` is login-shell setup
      # (it exports HOMEBREW_PREFIX / _CELLAR / _REPOSITORY and extends
      # MANPATH and INFOPATH, not just PATH), and the PATH block below is
      # guarded by `command -v brew`, so brew must already resolve by then.
      #
      # Pre-nix this lived in a hand-written ~/.zprofile that home-manager now
      # owns and overwrites — which is exactly how it went missing.
      programs.zsh.profileExtra = lib.mkIf pkgs.stdenv.isDarwin ''
        [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      '';

      programs.zsh.initContent = lib.mkIf pkgs.stdenv.isDarwin (
        lib.mkOrder 600 ''
          # ─── PATH additions (Mac) ─────────────────────────────────────
          # Helper: prepend if not already on PATH
          _prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
          _append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }

          # Personal/local
          #
          # ~/.cargo/bin holds whatever `cargo install` has put there, which
          # is a different set on each machine — wasm tooling, cargo-binstall
          # and cargo-generate on brett-m1-mbp; cargo-chef, cargo-watch and
          # sqlx on brett-mac-mini. Pre-nix a hand-written ~/.zshenv sourced
          # ~/.cargo/env; home-manager now owns .zshenv, so that line went
          # with it and every one of those binaries fell off PATH on both
          # Macs. Same failure as the brew shellenv in .zprofile below:
          # home-manager takes over a file that had hand-written content.
          #
          # Prepended HERE, ahead of the brew block, so the rustup shims still
          # win — that block's _prepend calls run later and therefore land
          # further forward. This restores the pre-nix ordering, where brew's
          # shellenv ran after ~/.cargo/env. Verified on brett-mac-mini after
          # a rebuild: rustup/bin at PATH position 4 and ~/.cargo/bin at 10,
          # with cargo, rustc and rust-analyzer all resolving through rustup.
          _prepend "$HOME/.cargo/bin"
          _prepend "$HOME/.local/bin"
          _prepend "$HOME/.amplify/bin"
          _prepend "$HOME/.yarn/bin"
          _prepend "$HOME/.config/yarn/global/node_modules/.bin"
          _append  "$HOME/go/bin"
          _append  "$HOME/.docker/bin"

          # Homebrew-prefixed bins (resolved at shell-init time, not nix-eval time)
          if command -v brew >/dev/null 2>&1; then
            _prepend "$(brew --prefix ruby)/bin"
            _prepend "$(brew --prefix rustup)/bin"
            _prepend "/opt/homebrew/opt/ccache/libexec"
            _prepend "/opt/homebrew/opt/openjdk@17/bin"
          fi

          # Android SDK
          [ -n "$ANDROID_HOME" ] && {
            _append "$ANDROID_HOME/emulator"
            _append "$ANDROID_HOME/tools"
            _append "$ANDROID_HOME/tools/bin"
            _append "$ANDROID_HOME/platform-tools"
          }

          # pnpm
          [ -n "$PNPM_HOME" ] && _prepend "$PNPM_HOME"

          # GHCup (Haskell)
          [ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

          export PATH

          # ─── Machine-local secrets / work config ──────────────────────
          # Sensitive, machine-specific values (internal hostnames, secret
          # lookup IDs, work tokens, AWS instance aliases) live OUTSIDE this
          # PUBLIC repo in an untracked file. See
          # modules/home/shell/local.zsh.example for the expected contents,
          # including the lazy per-group secret loading that keeps this
          # source out of the startup path entirely.
          [ -f "$HOME/.config/zsh/local.zsh" ] && . "$HOME/.config/zsh/local.zsh"
        ''
      );
    };
}
