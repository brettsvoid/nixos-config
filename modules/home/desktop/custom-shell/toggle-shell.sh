# toggle-shell {custom|restart|ambxst|caelestia|status}: switches the session's shell.
# custom-shell.nix puts before this: $qs (Quickshell with the shell's modules), qs_env
# (the environment the shell runs in) and the snippet that finds the live Hyprland.

# The runtime directory, which no reboot keeps.
CUSTOM_PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/custom-shell.pid"

AMBXST_PATTERN="quickshell.*ambxst-shell"
# The qs process runs with `-p <store>/share/caelestia-shell`.
CAELESTIA_PATTERN="share/caelestia-shell"

ambxst_running() {
  pgrep -f "$AMBXST_PATTERN" >/dev/null 2>&1
}

# The pid file can outlive the shell (a session left without logging out), and the pid
# be another process's by now; at login that would leave the session without a shell.
custom_running() {
  [ -f "$CUSTOM_PID_FILE" ] || return 1
  local pid
  pid=$(cat "$CUSTOM_PID_FILE")
  kill -0 "$pid" 2>/dev/null \
    && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "quickshell/custom-shell"
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

# Waits for it to exit (2 s at most), as the next one may start straight after:
# Hyprland refuses a global shortcut another program still holds, with a protocol
# error that ends the new shell.
stop_custom() {
  if custom_running; then
    echo "Stopping custom shell..."
    pid=$(cat "$CUSTOM_PID_FILE")
    kill "$pid" 2>/dev/null
    for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -9 "$pid" 2>/dev/null
    rm -f "$CUSTOM_PID_FILE"
  fi
}

stop_caelestia() {
  if caelestia_running; then
    echo "Stopping Caelestia..."
    caelestia shell -k >/dev/null 2>&1 || pkill -f "$CAELESTIA_PATTERN" 2>/dev/null
    sleep 0.5
  fi
}

start_custom() {
  echo "Starting custom shell..."
  qs_env
  # Quickshell's own log misses the last words of a shell killed by a Wayland protocol
  # error (Qt exits at once); its output keeps them.
  "$qs" -p "$HOME/.config/quickshell/custom-shell" \
    >"${XDG_RUNTIME_DIR:-/tmp}/custom-shell.log" 2>&1 &
  echo $! >"$CUSTOM_PID_FILE"
  echo "Custom shell started (pid $!)"
  # mako starts on demand whenever nothing owns the notification service, so it may
  # hold it now. The shell takes the service as soon as mako lets go.
  systemctl --user stop mako.service 2>/dev/null || true
}

case "${1:-}" in
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
    start_custom
    ;;
  restart)
    # The custom shell again, on the config installed now: a running one keeps the
    # config it started with. A rebuild that changes it runs this (the onChange in
    # custom-shell.nix). Not while the session is locked: the lock screen is the
    # shell's, and a lock whose program dies leaves the session stuck (lock-recover).
    if ! custom_running; then
      echo "Custom shell not running"
      exit 0
    fi
    if hyprctl -j locked | jq -e .locked >/dev/null; then
      echo "The session is locked; restart the custom shell once unlocked" >&2
      exit 1
    fi
    stop_custom
    start_custom
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
    # ambxst binds its keys at runtime; a reload drops them so they cannot fire
    # alongside Caelestia's.
    hyprctl reload >/dev/null
    echo "Starting Caelestia..."
    caelestia shell -d >/dev/null 2>&1
    echo "Caelestia started"
    ;;
  *)
    echo "Usage: toggle-shell {custom|restart|ambxst|caelestia|status}"
    echo ""
    echo "  custom     - Stop the other shells, start custom shell"
    echo "  restart    - Restart the custom shell if running (to load a rebuild)"
    echo "  ambxst     - Stop the other shells, restart ambxst"
    echo "  caelestia  - Stop the other shells, start Caelestia"
    echo "  status     - Show which shell is running"
    exit 1
    ;;
esac
