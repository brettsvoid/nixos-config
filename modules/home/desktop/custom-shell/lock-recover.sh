# lock-recover: from a text console (Ctrl+Alt+F2, log in), when the lock screen has
# died or will not take the password. Starts the custom shell again and, once you are
# back on Hyprland's VT, has it lock, so the password unlocks (docs/lock-screen.md).
# Hyprland lets a new lock take over only while misc:allow_session_lock_restore is on,
# which would let any program replace a working lock too, so it is on just for these
# few seconds.
set -u
hypr() { hyprctl --instance 0 "$@"; }
if ! hypr version >/dev/null 2>&1; then
  echo "Hyprland is not running" >&2
  exit 1
fi

pidfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/custom-shell.pid"
pid=$(cat "$pidfile" 2>/dev/null)
# Only while that pid is still the shell: the file can outlive it (a session left
# without logging out), and the pid be another process's by now.
if [ -n "$pid" ] && tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "quickshell/custom-shell"; then
  echo "Stopping the custom shell..."
  kill "$pid"
  for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  kill -9 "$pid" 2>/dev/null
  rm -f "$pidfile"
fi

echo "Starting the custom shell..."
hypr dispatch exec toggle-shell custom >/dev/null
started=false
for _ in $(seq 50); do
  if hypr globalshortcuts -j | jq -e 'any(.[]; .name == "custom-shell:lock")' >/dev/null; then
    started=true
    break
  fi
  sleep 0.2
done
last_resort() {
  echo "Last resort, which ends the session and loses unsaved work:" >&2
  echo "  hyprctl --instance 0 dispatch exit" >&2
}
if ! $started; then
  echo "The custom shell did not start within 10 s, so nothing could lock." >&2
  last_resort
  exit 1
fi

# A lock asked for while Hyprland's VT is in the background breaks: the shell died
# with a Wayland protocol error both times it was tried from here, and locked once
# Hyprland's VT was showing (2026-10-10). So lock only once you are back there.
# Hyprland's VT is its logind session's.
hpid=$(hyprctl instances -j | jq -r 'sort_by(-.time) | .[0].pid')
vt=$(loginctl show-session "$(cat "/proc/$hpid/sessionid")" -p VTNr --value 2>/dev/null)
vt=${vt:-1}
echo "Now press Ctrl+Alt+F$vt: the lock screen appears there a few seconds later."
for _ in $(seq 300); do
  [ "$(cat /sys/class/tty/tty0/active)" = "tty$vt" ] && break
  sleep 1
done
if [ "$(cat /sys/class/tty/tty0/active)" != "tty$vt" ]; then
  echo "tty$vt was not showing within 5 minutes; run lock-recover again." >&2
  exit 1
fi
# Hyprland sets its monitors up again as its VT comes back.
sleep 2

hypr keyword misc:allow_session_lock_restore 1 >/dev/null
hypr dispatch global custom-shell:lock >/dev/null
sleep 2
hypr keyword misc:allow_session_lock_restore 0 >/dev/null

# You are on tty$vt by now: this is for when you come back here.
sleep 2
if kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
  echo "Locked by the custom shell. Once unlocked, log out here with exit."
else
  echo "The custom shell died while locking; its output is in" >&2
  echo "${XDG_RUNTIME_DIR:-/tmp}/custom-shell.log. Run lock-recover again." >&2
  last_resort
  exit 1
fi
