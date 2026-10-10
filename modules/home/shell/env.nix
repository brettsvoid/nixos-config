# Environment variables and PATH additions. Only the Macs import this
# module; Linux hosts get their PATH from the system profiles.
#
# Secrets and machine-specific config stay out of this public repo, in two
# untracked files sourced below: ~/.env_vars and ~/.config/zsh/local.zsh
# (see local.zsh.example).
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
      };

      # ~/.env_vars: plaintext, mode 600, exports BWS_ACCESS_TOKEN and a few
      # API keys. Source it from .zshenv, not .zshrc: local.zsh only installs
      # its secret loader if BWS_ACCESS_TOKEN is already set, and otherwise
      # no secret ever loads.
      #
      # Work secrets stay in Bitwarden Secrets Manager, not agenix, on
      # purpose: local.zsh holds only lookup IDs, so a key rotates in the
      # Bitwarden UI with no rebuild. agenix is for host secrets
      # (docs/SECRETS.md).
      programs.zsh.envExtra = ''
        [ -f "$HOME/.env_vars" ] && source "$HOME/.env_vars"
      '';

      # Put Homebrew on PATH, by absolute path. /etc/paths(.d) and
      # nix-darwin's environment.systemPath omit /opt/homebrew/bin, and the
      # bare-name `eval "$(brew shellenv 2>/dev/null || true)"` that
      # nix-homebrew adds to /etc/zshrc finds no brew, silently.
      #
      # profileExtra, not initContent: shellenv is login-shell setup (it also
      # exports HOMEBREW_* and extends MANPATH and INFOPATH), and the PATH
      # block below needs `command -v brew` to succeed.
      programs.zsh.profileExtra = lib.mkIf pkgs.stdenv.isDarwin ''
        [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      '';

      programs.zsh.initContent = lib.mkIf pkgs.stdenv.isDarwin (
        lib.mkOrder 600 ''
          # ─── PATH additions (Mac) ─────────────────────────────────────
          # Helper: prepend if not already on PATH
          _prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
          _append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }

          # Personal/local. ~/.cargo/bin (`cargo install` output) comes
          # before the brew block, whose later _prepend puts rustup's bin in
          # front of it, so rustup's cargo/rustc shims win.
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
          # Untracked; see modules/home/shell/local.zsh.example.
          [ -f "$HOME/.config/zsh/local.zsh" ] && . "$HOME/.config/zsh/local.zsh"
        ''
      );
    };
}
