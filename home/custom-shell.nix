{ config, pkgs, quickshell, ... }:

let
  qsPkg = quickshell.packages.x86_64-linux.default;

  toggle-shell = pkgs.writeShellScriptBin "toggle-shell" ''
    CUSTOM_PID_FILE="/tmp/custom-shell.pid"

    AMBXST_PATTERN="quickshell.*ambxst-shell"

    ambxst_running() {
      pgrep -f "$AMBXST_PATTERN" >/dev/null 2>&1
    }

    custom_running() {
      [ -f "$CUSTOM_PID_FILE" ] && kill -0 "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
    }

    case "''${1:-}" in
      status)
        echo "ambxst:       $(ambxst_running && echo "running (pid $(pgrep -f "$AMBXST_PATTERN" | head -1))" || echo "stopped")"
        echo "custom-shell: $(custom_running && echo "running (pid $(cat "$CUSTOM_PID_FILE"))" || echo "stopped")"
        ;;
      custom)
        if custom_running; then
          echo "Custom shell already running"
          exit 0
        fi
        echo "Stopping ambxst..."
        if ambxst_running; then
          pkill -f "$AMBXST_PATTERN" 2>/dev/null
          sleep 0.5
        fi
        echo "Starting custom shell..."
        export QSG_RHI_BACKEND=vulkan
        ${qsPkg}/bin/qs -p "$HOME/.config/quickshell/custom-shell" >/dev/null 2>&1 &
        echo $! > "$CUSTOM_PID_FILE"
        echo "Custom shell started (pid $!)"
        ;;
      ambxst)
        if ambxst_running; then
          echo "ambxst already running"
          exit 0
        fi
        echo "Stopping custom shell..."
        if custom_running; then
          kill "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
          rm -f "$CUSTOM_PID_FILE"
          sleep 0.5
        fi
        echo "Starting ambxst..."
        ambxst >/dev/null 2>&1 &
        echo "ambxst restarted"
        ;;
      *)
        echo "Usage: toggle-shell {custom|ambxst|status}"
        echo ""
        echo "  custom  - Kill ambxst, start custom shell"
        echo "  ambxst  - Kill custom shell, restart ambxst"
        echo "  status  - Show which shell is running"
        exit 1
        ;;
    esac
  '';

  matugenDir = ../quickshell/matugen;

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
    ${pkgs.matugen}/bin/matugen image "$WALLPAPER" \
      --source-color-index 0 \
      -c "$CONFIG_DIR/config.toml" \
      -t "$SCHEME" \
      -m "$MODE"

    ${pkgs.jq}/bin/jq -n \
      --arg wall "$WALLPAPER" \
      --arg scheme "$SCHEME" \
      --arg mode "$MODE" \
      '{currentWall: $wall, scheme: $scheme, mode: $mode}' > "$CACHE_DIR/wallpaper.json"

    echo "Theme saved to $CACHE_DIR/colors.json"
  '';

  qs-dev = pkgs.writeShellScriptBin "qs-dev" ''
    SHELL_DIR="''${1:-/home/brett/nixos-config/quickshell}"
    if [ ! -f "$SHELL_DIR/shell.qml" ]; then
      echo "Error: $SHELL_DIR/shell.qml not found"
      exit 1
    fi
    echo "Starting quickshell from $SHELL_DIR (Ctrl+C to stop)"
    echo "Runs ON TOP of ambxst -- nothing killed."
    export QSG_RHI_BACKEND=vulkan
    exec ${qsPkg}/bin/qs -p "$SHELL_DIR"
  '';
in
{
  home.packages = [
    qsPkg
    toggle-shell
    qs-dev
    generate-theme
  ];

  xdg.configFile."quickshell/custom-shell".source = ../quickshell;

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
}
