# Shell functions: things too complex for a one-line alias.
_: {
  flake.modules.homeManager.shell-functions =
    {
      lib,
      pkgs,
      ...
    }:
    {
      programs.zsh.initContent = lib.mkOrder 700 (
        ''
          # Yazi: cd to wherever you exit the file manager
          # https://yazi-rs.github.io/docs/quick-start
          yy() {
            local tmp
            tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
            yazi "$@" --cwd-file="$tmp"
            if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
              builtin cd -- "$cwd"
            fi
            rm -f -- "$tmp"
          }

          # Conda lazy-loader: only invoke conda's slow init when first used.
          conda() {
            unset -f conda
            if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
              . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
            else
              __setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
              [ $? -eq 0 ] && eval "$__setup" || \
                export PATH="/opt/homebrew/anaconda3/bin:$PATH"
              unset __setup
            fi
            conda "$@"
          }
        ''
        + lib.optionalString pkgs.stdenv.isDarwin ''

          # VS Code launcher (Mac): preserve $PWD via VSCODE_CWD
          code() {
            VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args "$@"
          }

          # Sketchybar brew wrapper: bumps the brew-package count widget
          # whenever brew state could have changed.
          if command -v sketchybar >/dev/null 2>&1; then
            brew() {
              command brew "$@"
              case "$*" in
                *upgrade*|*update*|*outdated*|*list*|*install*|*uninstall*|*bundle*|*doctor*|*info*|*cleanup*)
                  sketchybar --trigger brew_update
                  ;;
              esac
            }
          fi
        ''
      );
    };
}
