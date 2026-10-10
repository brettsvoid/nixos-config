# Game mode: hands the compositor's time to the game, under any shell. `game-mode on`
# turns off animations, shadows and blur, sets gaps, rounding and the border to their
# minimum, and allows tearing; `game-mode off` puts every one of those back as it was.
# Super+Shift+G toggles it.
#
# Off restores the values saved when it went on rather than running `hyprctl reload`:
# a reload re-reads the whole config, which also drops binds other programs added at
# runtime (Caelestia adds some) and re-applies the monitor rules.
#
# The state is in $XDG_RUNTIME_DIR/game-mode/state, "on" or "off", for a shell to show
# and watch; other programs change it by running `game-mode`. CPU-side tuning is Feral
# GameMode's job (profile-gaming) and is not touched here.
#
# Tearing: game mode turns on `general:allow_tearing`, the master switch. Hyprland only
# tears for a fullscreen window that is alone on its monitor, with no hardware cursor
# showing, on a monitor that supports async flips, and only if the window allows it:
# either the game asks through the tearing-control protocol, or a window rule marks it
# `immediate`. Game mode adds no such rules; a game that should tear (lower latency,
# at the cost of tearing and of VRR's smoothness) needs its own rule.
_: {
  flake.modules.homeManager.desktop-game-mode =
    { pkgs, lib, ... }:
    let
      game-mode = pkgs.writeShellScriptBin "game-mode" ''
        set -eu
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
            pkgs.libnotify
          ]
        }:$PATH
        DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/game-mode"
        STATE="$DIR/state"
        # The values to put back, one `keyword <option> <value>` per line.
        SAVED="$DIR/saved"
        OPTIONS="animations:enabled decoration:shadow:enabled decoration:blur:enabled general:gaps_in general:gaps_out general:border_size decoration:rounding general:allow_tearing"

        status() {
          if [ "$(cat "$STATE" 2>/dev/null)" = on ]; then echo on; else echo off; fi
        }

        write_state() {
          mkdir -p "$DIR"
          echo "$1" > "$STATE.tmp"
          mv "$STATE.tmp" "$STATE"
        }

        notify() {
          notify-send -a "Game mode" -t 2000 \
            -h string:x-canonical-private-synchronous:game-mode "$1" "$2" || true
        }

        on() {
          [ "$(status)" = on ] && return 0
          mkdir -p "$DIR"
          : > "$SAVED.tmp"
          for option in $OPTIONS; do
            # An int, a float or a custom string such as "8 8 8 8".
            value=$(hyprctl getoption "$option" -j | jq -r '.int // .float // .custom // empty')
            [ -n "$value" ] && echo "keyword $option $value" >> "$SAVED.tmp"
          done
          mv "$SAVED.tmp" "$SAVED"
          # One batch, so nothing renders half-applied.
          hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword general:allow_tearing 1" >/dev/null
          write_state on
          notify "Game mode on" "Animations, blur, shadows, gaps and rounding are off."
        }

        off() {
          [ "$(status)" = off ] && return 0
          if [ -s "$SAVED" ]; then
            hyprctl --batch "$(paste -sd ';' "$SAVED")" >/dev/null
          else
            # Nothing saved to go back to: fall back to the config.
            hyprctl reload >/dev/null
          fi
          write_state off
          notify "Game mode off" "The desktop is back as it was."
        }

        case "''${1:-status}" in
          on) on ;;
          off) off ;;
          toggle) if [ "$(status)" = on ]; then off; else on; fi ;;
          status) status ;;
          *)
            echo "Usage: game-mode {on|off|toggle|status}" >&2
            exit 2
            ;;
        esac
      '';
    in
    {
      home.packages = [ game-mode ];

      wayland.windowManager.hyprland.settings.bindd = [
        "$mod SHIFT, G, Toggle game mode, exec, game-mode toggle"
      ];
    };
}
