# Environment variables and PATH additions, mostly Mac-specific. Linux
# hosts get their PATH from system-side profiles, not from a per-user
# initExtra block.
#
# The bws (Bitwarden Secrets) lookups currently fetch tokens at every
# shell startup — a known slow-shell smell. Phase G migrates them to
# agenix-decrypted files in /run.
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

          # ─── Secrets (bws — runtime fetched; Phase G replaces with agenix) ──
          # Each fetch falls back to empty on failure so a missing
          # BWS_ACCESS_TOKEN doesn't break the shell.
          if command -v bws >/dev/null 2>&1 && [ -n "''${BWS_ACCESS_TOKEN:-}" ]; then
            _bws() {
              bws secret get "$1" --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null \
                | jq -r '.value' 2>/dev/null
            }

            # Nomad (tyto)
            export NOMAD_ADDR="http://54.242.249.179:4646"
            export NOMAD_OPERATOR_TOKEN="$(_bws 5536b6b7-3e62-469f-b3e2-b43c00fb0d05)"
            export NOMAD_TOKEN="$NOMAD_OPERATOR_TOKEN"

            # Sentry MCP / release auth
            export SENTRY_ACCESS_TOKEN_CLAUDE="$(_bws 59d40097-f5d2-4fd3-bc0d-b3d400f0a9f8)"
            export SENTRY_ACCESS_TOKEN_MCP="$SENTRY_ACCESS_TOKEN_CLAUDE"
            export SENTRY_AUTH_TOKEN="$(_bws a989a33a-ba80-4b35-a7a6-b43501105747)"

            # Grafana (tyto)
            export GRAFANA_TOKEN_TYTO_CLAUDE_MCP="$(_bws cf5d5904-b72e-4abf-be6c-b43c009bcc22)"
            export GRAFANA_SERVICE_ACCOUNT_TOKEN_MCP="$GRAFANA_TOKEN_TYTO_CLAUDE_MCP"
          fi
        ''
      );
    };
}
