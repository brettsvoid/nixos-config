# Environment variables and PATH additions, mostly Mac-specific. Linux
# hosts get their PATH from system-side profiles, not from a per-user
# initExtra block.
#
# Secrets and machine-specific config are NOT kept here (this repo is
# public). They're sourced at shell init from an untracked
# ~/.config/zsh/local.zsh — see local.zsh.example for the template.
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

      programs.zsh.initContent = lib.mkIf pkgs.stdenv.isDarwin (
        lib.mkOrder 600 ''
          # ─── PATH additions (Mac) ─────────────────────────────────────
          # Helper: prepend if not already on PATH
          _prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
          _append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }

          # Personal/local
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
          # modules/home/shell/local.zsh.example for the expected contents.
          # (Longer term this migrates to agenix — see modules/flake/agenix.nix.)
          [ -f "$HOME/.config/zsh/local.zsh" ] && . "$HOME/.config/zsh/local.zsh"
        ''
      );
    };
}
