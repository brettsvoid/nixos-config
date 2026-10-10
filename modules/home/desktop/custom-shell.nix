# Custom Quickshell-based bar with matugen-generated theme. Coexists with
# ambxst (the prior bar) and, where desktop-caelestia is imported, the
# Caelestia trial; `toggle-shell` switches between them.
{ inputs, config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.desktop-custom-shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Qt loads shaders as .qsb, so each one under quickshell/shaders is compiled
      # here and by qs-dev. A shader that does not compile fails the build.
      compileShaders = dir: ''
        for shader in "${dir}"/shaders/*.frag "${dir}"/shaders/*.vert; do
          [ -e "$shader" ] || continue
          ${pkgs.qt6.qtshadertools}/bin/qsb --qt6 -o "$shader.qsb" "$shader" || exit 1
        done
      '';

      # Quickshell only knows hicolor unless told the icon theme; use the GTK one, so
      # the launcher's icons match every other app's.
      iconThemeEnv = lib.optionalString (
        config.gtk.iconTheme != null
      ) "export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}";

      # `custom-shell-or <drawer> <fallback...>` opens one of the custom shell's drawers
      # while that shell runs (its global shortcut is registered), and runs the fallback
      # under the other shells. It keeps Super+R and Super+/ working everywhere until
      # the custom shell is the session's shell (custom-shell issue 22), which binds the
      # globals directly and drops Fuzzel.
      custom-shell-or = pkgs.writeShellScriptBin "custom-shell-or" ''
        drawer=$1
        shift
        if hyprctl globalshortcuts -j | ${pkgs.jq}/bin/jq -e --arg name "custom-shell:$drawer" 'any(.[]; .name == $name)' >/dev/null; then
          exec hyprctl dispatch global "custom-shell:$drawer"
        fi
        exec "$@"
      '';

      shellConfig = pkgs.runCommand "custom-shell-config" { } ''
        cp -r ${./quickshell} $out
        chmod -R u+w $out
        ${compileShaders "$out"}
      '';

      toggle-shell = pkgs.writeShellScriptBin "toggle-shell" ''
        CUSTOM_PID_FILE="/tmp/custom-shell.pid"

        AMBXST_PATTERN="quickshell.*ambxst-shell"
        # The qs process runs with `-p <store>/share/caelestia-shell`.
        CAELESTIA_PATTERN="share/caelestia-shell"

        ambxst_running() {
          pgrep -f "$AMBXST_PATTERN" >/dev/null 2>&1
        }

        custom_running() {
          [ -f "$CUSTOM_PID_FILE" ] && kill -0 "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
        }

        caelestia_running() {
          pgrep -f "$CAELESTIA_PATTERN" >/dev/null 2>&1
        }

        stop_ambxst() {
          if ambxst_running; then
            echo "Stopping ambxst..."
            pkill -f "$AMBXST_PATTERN" 2>/dev/null
            sleep 0.5
          fi
        }

        stop_custom() {
          if custom_running; then
            echo "Stopping custom shell..."
            kill "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
            rm -f "$CUSTOM_PID_FILE"
            sleep 0.5
          fi
        }

        stop_caelestia() {
          if caelestia_running; then
            echo "Stopping Caelestia..."
            caelestia shell -k >/dev/null 2>&1 || pkill -f "$CAELESTIA_PATTERN" 2>/dev/null
            sleep 0.5
          fi
        }

        case "''${1:-}" in
          status)
            echo "ambxst:       $(ambxst_running && echo "running (pid $(pgrep -f "$AMBXST_PATTERN" | head -1))" || echo "stopped")"
            echo "custom-shell: $(custom_running && echo "running (pid $(cat "$CUSTOM_PID_FILE"))" || echo "stopped")"
            echo "caelestia:    $(caelestia_running && echo "running (pid $(pgrep -f "$CAELESTIA_PATTERN" | head -1))" || echo "stopped")"
            ;;
          custom)
            if custom_running; then
              echo "Custom shell already running"
              exit 0
            fi
            stop_ambxst
            stop_caelestia
            echo "Starting custom shell..."
            export QSG_RHI_BACKEND=vulkan
            ${iconThemeEnv}
            ${qsPkg}/bin/qs -p "$HOME/.config/quickshell/custom-shell" >/dev/null 2>&1 &
            echo $! > "$CUSTOM_PID_FILE"
            echo "Custom shell started (pid $!)"
            ;;
          ambxst)
            if ambxst_running; then
              echo "ambxst already running"
              exit 0
            fi
            stop_custom
            stop_caelestia
            echo "Starting ambxst..."
            ambxst >/dev/null 2>&1 &
            echo "ambxst restarted"
            ;;
          caelestia)
            if ! command -v caelestia >/dev/null 2>&1; then
              echo "Caelestia is not installed on this host (desktop-caelestia)" >&2
              exit 1
            fi
            if caelestia_running; then
              echo "Caelestia already running"
              exit 0
            fi
            stop_ambxst
            stop_custom
            # ambxst binds its keys at runtime; a reload drops them so they
            # cannot fire alongside Caelestia's.
            hyprctl reload >/dev/null
            echo "Starting Caelestia..."
            caelestia shell -d >/dev/null 2>&1
            echo "Caelestia started"
            ;;
          *)
            echo "Usage: toggle-shell {custom|ambxst|caelestia|status}"
            echo ""
            echo "  custom     - Stop the other shells, start custom shell"
            echo "  ambxst     - Stop the other shells, restart ambxst"
            echo "  caelestia  - Stop the other shells, start Caelestia"
            echo "  status     - Show which shell is running"
            exit 1
            ;;
        esac
      '';

      matugenDir = ./quickshell/matugen;

      generate-theme = pkgs.writeShellScriptBin "generate-theme" ''
        CACHE_DIR="$HOME/.cache/qs-theme"
        CONFIG_DIR="${matugenDir}"
        mkdir -p "$CACHE_DIR"

        WALLPAPER=""
        SCHEME="scheme-neutral"
        MODE="light"

        # Parse args: generate-theme [wallpaper] [--scheme X] [--mode light|dark]
        while [ $# -gt 0 ]; do
          case "$1" in
            --scheme) SCHEME="$2"; shift 2 ;;
            --mode) MODE="$2"; shift 2 ;;
            --dark) MODE="dark"; shift ;;
            --light) MODE="light"; shift ;;
            *) WALLPAPER="$1"; shift ;;
          esac
        done

        if [ -z "$WALLPAPER" ]; then
          if [ -f "$CACHE_DIR/wallpaper.json" ]; then
            WALLPAPER=$(${pkgs.jq}/bin/jq -r '.currentWall // empty' "$CACHE_DIR/wallpaper.json")
            SAVED_SCHEME=$(${pkgs.jq}/bin/jq -r '.scheme // empty' "$CACHE_DIR/wallpaper.json")
            SAVED_MODE=$(${pkgs.jq}/bin/jq -r '.mode // empty' "$CACHE_DIR/wallpaper.json")
            [ -n "$SAVED_SCHEME" ] && SCHEME="$SAVED_SCHEME"
            [ -n "$SAVED_MODE" ] && MODE="$SAVED_MODE"
          fi
        fi

        if [ -z "$WALLPAPER" ]; then
          if [ -f "$HOME/.cache/ambxst/wallpapers.json" ]; then
            WALLPAPER=$(${pkgs.jq}/bin/jq -r '.currentWall // empty' "$HOME/.cache/ambxst/wallpapers.json")
          fi
        fi

        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          echo "Usage: generate-theme [wallpaper-path] [--scheme X] [--mode light|dark]"
          echo "Schemes: scheme-neutral, scheme-tonal-spot, scheme-content, scheme-fidelity,"
          echo "         scheme-expressive, scheme-fruit-salad, scheme-monochrome, scheme-rainbow"
          exit 1
        fi

        echo "Generating theme: $WALLPAPER (scheme: $SCHEME, mode: $MODE)"
        if ! ${pkgs.matugen}/bin/matugen image "$WALLPAPER" \
          --source-color-index 0 \
          -c "$CONFIG_DIR/config.toml" \
          -t "$SCHEME" \
          -m "$MODE"; then
          echo "matugen failed — theme not generated" >&2
          exit 1
        fi

        ${pkgs.jq}/bin/jq -n \
          --arg wall "$WALLPAPER" \
          --arg scheme "$SCHEME" \
          --arg mode "$MODE" \
          '{currentWall: $wall, scheme: $scheme, mode: $mode}' > "$CACHE_DIR/wallpaper.json"

        echo "Theme generated; selection saved to $CACHE_DIR/wallpaper.json"
      '';

      qs-dev = pkgs.writeShellScriptBin "qs-dev" ''
        SHELL_DIR="''${1:-$HOME/${repoDir}/modules/home/desktop/quickshell}"
        if [ ! -f "$SHELL_DIR/shell.qml" ]; then
          echo "Error: $SHELL_DIR/shell.qml not found"
          exit 1
        fi
        ${compileShaders "$SHELL_DIR"}
        echo "Starting quickshell from $SHELL_DIR (Ctrl+C to stop)"
        echo "Runs ON TOP of ambxst -- nothing killed."
        export QSG_RHI_BACKEND=vulkan
        ${iconThemeEnv}
        exec ${qsPkg}/bin/qs -p "$SHELL_DIR"
      '';
    in
    {
      home.packages = [
        qsPkg
        toggle-shell
        qs-dev
        generate-theme
        custom-shell-or
      ];

      xdg.configFile."quickshell/custom-shell".source = shellConfig;

      # The shell's drawers are Hyprland global shortcuts, like Caelestia's panels: each
      # does nothing while this shell is not running. Hyprland runs every bind that
      # matches a key, so this shares Super+Escape with Caelestia's and ambxst's menus.
      wayland.windowManager.hyprland.settings = {
        bindd = [
          "$mod, R, App launcher, exec, custom-shell-or launcher ${pkgs.fuzzel}/bin/fuzzel"
          "$mod, slash, Keybind cheatsheet, exec, custom-shell-or cheatsheet hypr-cheatsheet"
          "$mod, ESCAPE, Session menu (custom shell), global, custom-shell:session"
        ];
        # The brightness keys still run brightnessctl (hyprland.nix); this also tells
        # the shell, which shows the new level. The backlight sends no change events.
        binddel = [
          ", XF86MonBrightnessUp, Show the brightness level (custom shell), global, custom-shell:brightness"
          ", XF86MonBrightnessDown, Show the brightness level (custom shell), global, custom-shell:brightness"
        ];
      };

      home.activation.generateTheme = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        CACHE_DIR="$HOME/.cache/qs-theme"
        mkdir -p "$CACHE_DIR"

        if [ ! -f "$CACHE_DIR/colors.json" ]; then
          WALLPAPER=""
          if [ -f "$HOME/.cache/ambxst/wallpapers.json" ]; then
            WALLPAPER=$(${pkgs.jq}/bin/jq -r '.currentWall // empty' "$HOME/.cache/ambxst/wallpapers.json")
          fi
          if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
            ${pkgs.matugen}/bin/matugen image "$WALLPAPER" \
              --source-color-index 0 \
              -c "${matugenDir}/config.toml" \
              -t scheme-neutral \
              -m light || true
            ${pkgs.jq}/bin/jq -n --arg wall "$WALLPAPER" '{currentWall: $wall, scheme: "scheme-neutral", mode: "light"}' > "$CACHE_DIR/wallpaper.json"
          fi
        fi
      '';
    };
}
