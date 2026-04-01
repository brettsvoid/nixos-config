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
  ];

  xdg.configFile."quickshell/custom-shell".source = ../quickshell;
}
