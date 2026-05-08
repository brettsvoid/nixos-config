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

          # mkdir + cd in one command
          md() { mkdir -p "$@" && cd -- "$@"; }

          # Quick "what's this" — opens a Google search in the default browser
          wtf() { /usr/bin/open "http://www.google.com/search?q=$1"; }

          # cht.sh launcher: pick a language/util via fzf, prompt for a query,
          # fetch the cheatsheet from cht.sh.
          cht() {
            local languages="rust lua python typescript nodejs"
            local utils="xargs find mv sed awk"
            local selected
            selected="$(printf '%s\n%s' "$languages" "$utils" | tr ' ' '\n' | fzf)"
            [ -z "$selected" ] && return 1
            local query
            read "query?query: "
            if echo "$languages" | grep -qs "$selected"; then
              curl "cht.sh/$selected/''${query// /+}"
            else
              curl "cht.sh/$selected~$query"
            fi
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
