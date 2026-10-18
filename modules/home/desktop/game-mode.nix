# Game mode: hands the compositor's time to the game, under any shell. `game-mode on`
# turns off animations, shadows and blur, sets gaps, rounding and the border to their
# minimum, and allows tearing; `game-mode off` puts them back. Super+Shift+G toggles it.
#
# Feral GameMode also turns it on while a game runs, through `auto-on` and `auto-off`
# in ~/.config/gamemode.ini (below). auto-off only undoes what auto-on did, so a game
# ending never overrides a manual choice. A game opts in to GameMode by running under
# `gamemoderun`: in Steam, set its launch options to `gamemoderun %command%`, which
# also covers games started from the rofi game library.
#
# Turned on by hand, it also holds a GameMode request (`gamemoded -r`) until it is
# turned off, so a game started without gamemoderun still gets GameMode's CPU side.
# The hold starts after the state is written, so GameMode's own auto-on finds game
# mode on already and does nothing. auto-on takes no hold: one would keep GameMode
# active after the game, and its auto-off would never run.
#
# Off restores the values saved when it went on, not `hyprctl reload`: a reload also
# drops binds other programs added at runtime (Caelestia adds some) and re-applies the
# monitor rules.
#
# The state is $XDG_RUNTIME_DIR/game-mode, "on" or "off", for a shell to show; it sits
# directly in the runtime directory, which always exists, so a watcher sees it appear.
# Other programs change it by running `game-mode`. CPU-side tuning is Feral GameMode's
# job (profile-gaming).
#
# Tearing: this only sets general:allow_tearing, the master switch. Hyprland tears only
# for a fullscreen window alone on its monitor, with no hardware cursor showing, on a
# monitor that supports async flips, and only if the game asks (tearing-control
# protocol) or a window rule marks it `immediate`. Game mode adds no such rules.
{ config, ... }:
let
  inherit (config.flake.lib) liveHyprland;
in
{
  flake.modules.homeManager.desktop-game-mode =
    { pkgs, lib, ... }:
    let
      game-mode = pkgs.writeShellScriptBin "game-mode" ''
        set -eu
        # GameMode runs this with a bare PATH: hyprctl comes from the system profile, the
        # same Hyprland the session runs.
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
            pkgs.libnotify
          ]
        }:$PATH:/run/current-system/sw/bin
        DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        # Run from a service, the session's Hyprland may not be in the environment, and
        # run from an old terminal it may be one that has gone: take the running one.
        ${liveHyprland pkgs}
        STATE="$DIR/game-mode"
        # The values to put back, one `keyword <option> <value>` per line.
        SAVED="$DIR/game-mode.saved"
        # Present while game mode is on because a game started it (auto-on).
        AUTO="$DIR/game-mode.auto"
        # The pid of the GameMode request held while game mode is on by hand.
        HOLD="$DIR/game-mode.hold"
        OPTIONS="animations:enabled decoration:shadow:enabled decoration:blur:enabled general:gaps_in general:gaps_out general:border_size decoration:rounding general:allow_tearing"

        status() {
          if [ "$(cat "$STATE" 2>/dev/null)" = on ]; then echo on; else echo off; fi
        }

        write_state() {
          echo "$1" > "$STATE.tmp"
          mv "$STATE.tmp" "$STATE"
        }

        hold() {
          [ -e "$HOLD" ] && return 0
          command -v gamemoded >/dev/null || return 0
          setsid gamemoded -r >/dev/null 2>&1 &
          echo $! > "$HOLD"
        }

        # SIGINT ends the request at once; GameMode only notices a killed one later.
        release() {
          [ -e "$HOLD" ] || return 0
          pid=$(cat "$HOLD")
          if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = gamemoded ]; then
            kill -INT "$pid" || true
          fi
          rm -f "$HOLD"
        }

        notify() {
          notify-send -a "Game mode" -t 2000 \
            -h string:x-canonical-private-synchronous:game-mode "$1" "$2" || true
        }

        on() {
          [ "$(status)" = on ] && return 0
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
          release
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
          # By hand: whatever a game started, the user now decides.
          on) rm -f "$AUTO"; on; hold ;;
          off) rm -f "$AUTO"; off ;;
          toggle)
            rm -f "$AUTO"
            if [ "$(status)" = on ]; then off; else on; hold; fi
            ;;
          # From GameMode's start and end scripts.
          auto-on)
            if [ "$(status)" = off ]; then
              on
              : > "$AUTO"
            fi
            ;;
          auto-off)
            if [ -e "$AUTO" ]; then
              rm -f "$AUTO"
              off
            fi
            ;;
          status) status ;;
          *)
            echo "Usage: game-mode {on|off|toggle|status|auto-on|auto-off}" >&2
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

      # GameMode runs these through /bin/sh in its own environment, so the full path.
      # It reads this file as well as /etc/gamemode.ini and reloads it when it changes.
      xdg.configFile."gamemode.ini".text = ''
        [custom]
        start=${game-mode}/bin/game-mode auto-on
        end=${game-mode}/bin/game-mode auto-off
      '';
    };
}
