# Window open/close shader effects through HyprWindowShade
# (github:ManofJELLO/HyprWindowShade, MIT), a Hyprland plugin that runs a
# GLSL fragment shader over a window as it opens or closes. It shades the
# snapshot Hyprland keeps of a closing window, so it works however the window
# closes.
#
# The effects come from a library (window-dissolve/build-library.py builds it):
# our own (dissolve, a burn through a noise pattern with its ember edge off;
# fade; none, Hyprland's own animation) and two MIT collections of niri
# shaders, wrapped for the plugin at build time. `window-effect open|close
# <id>` picks one; `window-effect list` lists them. The shell's effect picker
# calls the same command. The choice lives in ~/.local/state/window-effects
# and survives a logout. Dissolve is the default for both.
#
# The plugin builds against Hyprland's internal headers. mkHyprlandPlugin uses
# pkgs.hyprland, the Hyprland programs.hyprland installs (home-manager uses
# the system's pkgs), so the two match after a rebuild.
#
# The window rules name two fixed files, open.glsl and close.glsl in that
# state folder, and window-effect copies the chosen effect over them. The
# plugin caches a shader by its path and recompiles when the file's mtime, in
# whole seconds, changes, so window-effect makes each new copy's mtime later
# than the last, even for two switches within a second. Links would not do:
# every file in the store has the same mtime.
#
# ~/.config/hypr/shaders links to window-dissolve/ in the repo checkout, not
# the store, for working on our own effects: `window-effect open <path>` uses
# a file as it is, and running it again after an edit shows the change on the
# next open or close, without a rebuild.
{ inputs, config, ... }:
let
  inherit (config.flake.lib) repoDir;
in
{
  flake.modules.homeManager.desktop-window-dissolve =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      stateDir = "${config.xdg.stateHome}/window-effects";

      # Every effect as a HyprWindowShade shader, a preview of it for the
      # shell's picker (Qt's shader format), and index.json. Every shader is
      # compiled here, as the plugin's GLSL ES 3.20 and as the preview: one of
      # ours that fails stops the build, and a ported one is left out (listed
      # in excluded.json), so a broken effect upstream never reaches a window.
      library =
        pkgs.runCommand "window-effects"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (p: [ p.kdl-py ]))
              pkgs.glslang
              pkgs.qt6.qtshadertools
            ];
          }
          ''
            python3 -I ${./window-dissolve/build-library.py} $out ${./window-dissolve} \
              --liixini ${inputs.niri-shaders} ${inputs.niri-shaders.rev} \
              --nirimation ${inputs.nirimation} ${inputs.nirimation.rev}
          '';

      # The effect in force for windows opening and closing.
      window-effect = pkgs.writeShellApplication {
        name = "window-effect";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.diffutils # cmp
          pkgs.jq
          pkgs.util-linux # column
        ];
        text = ''
          library=${library}
          state=${stateDir}
          default=dissolve

          usage() {
            echo "Usage: window-effect list [--json]" >&2
            echo "       window-effect status [--json]" >&2
            echo "       window-effect open|close <id or path to a .glsl>" >&2
            echo "       window-effect refresh" >&2
            exit 2
          }

          active() {
            jq -r --arg kind "$1" '.[$kind] // empty' "$state/active.json" 2>/dev/null || true
          }

          # Copies the shader over $state/<kind>.glsl, which the window rule
          # names. Written beside it and renamed, so the plugin never reads half
          # a file; its mtime made later than the old one's, as the plugin only
          # recompiles when the mtime (whole seconds) changes. Unchanged, it is
          # left alone, so a refresh after a rebuild recompiles only what changed.
          install_shader() {
            local kind=$1 source=$2 name=$3
            local target="$state/$kind.glsl"
            mkdir -p "$state"
            if ! cmp -s "$source" "$target"; then
              local old now
              old=$(stat -c %Y "$target" 2>/dev/null || echo 0)
              now=$(date +%s)
              cp "$source" "$target.new"
              chmod 644 "$target.new"
              touch -d "@$(( now > old ? now : old + 1 ))" "$target.new"
              mv -f "$target.new" "$target"
            fi
            local json='{}'
            [ -f "$state/active.json" ] && json=$(cat "$state/active.json")
            jq --arg kind "$kind" --arg name "$name" '.[$kind] = $name' <<<"$json" >"$state/active.json.new"
            mv -f "$state/active.json.new" "$state/active.json"
          }

          choose() {
            local kind=$1 choice=$2
            if [ -f "$choice" ]; then
              install_shader "$kind" "$choice" "$(realpath "$choice")"
            elif [ -f "$library/shaders/$choice-$kind.glsl" ]; then
              install_shader "$kind" "$library/shaders/$choice-$kind.glsl" "$choice"
            else
              echo "window-effect: no $kind effect \"$choice\" (window-effect list)" >&2
              exit 1
            fi
          }

          case "''${1:-}" in
            list)
              if [ "''${2:-}" = --json ]; then
                cat "$library/index.json"
              else
                jq -r '.[] | "\(.id)\t\(.name) (\(.source))\t\([if .open then "open" else empty end, if .close then "close" else empty end] | join(" "))"' "$library/index.json" | column -t -s "$(printf '\t')"
              fi
              ;;
            status)
              if [ "''${2:-}" = --json ]; then
                cat "$state/active.json" 2>/dev/null || echo '{}'
              else
                echo "open:  $(active open)"
                echo "close: $(active close)"
              fi
              ;;
            open | close)
              [ $# -eq 2 ] || usage
              choose "$1" "$2"
              ;;
            refresh)
              # After a rebuild: the active effects again from the new library
              # (or a file chosen by path, as it is now). One no longer in the
              # library falls back to the default.
              for kind in open close; do
                choice=$(active "$kind")
                if [ -z "$choice" ] || { [ ! -f "$choice" ] && [ ! -f "$library/shaders/$choice-$kind.glsl" ]; }; then
                  [ -n "$choice" ] && echo "window-effect: \"$choice\" is gone; $kind is $default again" >&2
                  choice=$default
                fi
                choose "$kind" "$choice"
              done
              ;;
            *) usage ;;
          esac
        '';
      };

      plugin = pkgs.hyprlandPlugins.mkHyprlandPlugin {
        pluginName = "hyprwindowshade";
        version = "0-unstable-2026-09-18";
        src = inputs.hyprwindowshade;

        # The Makefile's default target builds HyprWindowShade.so in the
        # source root.
        installPhase = ''
          runHook preInstall
          install -Dm755 HyprWindowShade.so $out/lib/libhyprwindowshade.so
          runHook postInstall
        '';

        meta = {
          description = "Per-window and per-layer fragment shaders for Hyprland, with open and close animations";
          homepage = "https://github.com/ManofJELLO/HyprWindowShade";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      };
    in
    {
      xdg.configFile."hypr/shaders".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/desktop/window-dissolve";

      # The shell's effect picker reads index.json and the previews here.
      xdg.dataFile."window-effects".source = library;

      home.packages = [ window-effect ];

      # The window rules always name a shader, so the files exist from the
      # first login, and a rebuild brings the active effects up to date.
      home.activation.windowEffects = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        run ${window-effect}/bin/window-effect refresh
      '';

      wayland.windowManager.hyprland.settings = {
        # Loaded once the session is up, not by a `plugin =` line while the
        # config is parsed: a plugin that fails then takes Hyprland down on
        # every login (the plugin's README), while here it costs the effect
        # for one session. exec-once does not rerun on a rebuild: after the
        # plugin changes, `hyprctl plugin unload`/`load` it or log in again.
        exec-once = [ "hyprctl plugin load ${plugin}/lib/libhyprwindowshade.so" ];

        # Windows grow in from 85% while the open shader plays. A close needs
        # no Hyprland animation unless the shader asks for one (`// @overlay`,
        # as fade and none do): otherwise the plugin holds the window still
        # and the shader does its own shrink. windowsIn and fadeIn are set
        # explicitly, so desktop-hyprland's `windows` and `fade` lines do not
        # override them. Speed is in tenths of a second: 3 matches the default
        # dissolve-open.glsl's `@duration`, so popin, fade-in and burn end
        # together. Other effects run for their own length over the popin.
        animations.animation = [
          "windowsIn, 1, 3, ease, popin 85%"
          "fadeIn, 1, 3, ease"
        ];

        # A `tag` on a window rule picks the shader; `+shader_open:` and
        # `+shader_close:` play it once as the window opens or closes. The
        # plugin skips fullscreen windows unless a rule opts them in, so a
        # fullscreen game costs nothing. Menus and tooltips borrow their
        # window's shader, which only matters while that window is opening. To
        # exclude an app, add a rule after these that removes both tags, e.g.
        # "tag -shader_open:${stateDir}/open.glsl, match:class ^(app)$"
        # and the same with -shader_close.
        windowrule = [
          "tag +shader_open:${stateDir}/open.glsl, match:class .*"
          "tag +shader_close:${stateDir}/close.glsl, match:class .*"
        ];
      };
    };
}
