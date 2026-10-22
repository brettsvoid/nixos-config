# qs-test: runs the custom shell apart from the desktop, to test it, then reports.
# custom-shell.nix puts before this: $qs, $sway, $dbus_config, $fake_hyprland,
# $default_config, $alarm_sound and compile_shaders.

usage() {
  cat <<'EOF'
Usage: qs-test [-c config] [-t seconds] [-s screens] [-m monitors] [--check] [-- command...]

Runs the custom shell apart from the desktop and reports what it logged.

  -c config   The shell's folder (default: the repo's modules/home/desktop/quickshell).
  -t seconds  How long the shell runs when no command is given (default 5).
  -s screens  How many outputs sway makes: HEADLESS-1, HEADLESS-2... (default 1).
  -m monitors A file in `hyprctl monitors -j`'s shape, for the fake Hyprland to answer
              with, for example to give the outputs descriptions. A command can also
              write $QS_TEST/monitors.json and send `configreloaded>>`.
  --check     Exit 1 if the shell did not load or logged a QML error or warning.
  -- command  Run this once the shell has loaded, then stop it. The command sees
              QS_TEST (the test folder) and QS_CONFIG (the shell's folder) and the
              shell's environment, so `qs ipc -p "$QS_CONFIG" call ...` reaches it.

The shell runs in a headless sway (software rendering), so its panel windows are
created as on the desktop, on its own session bus, with its own config, state, cache,
data and runtime folders under $QS_TEST. Its settings start at their defaults, in
$QS_TEST/xdg-config/custom-shell/settings.json; a command can write that file and the
shell applies it. Commands that would change the desktop (hyprctl,
generate-theme, game-mode, session-exit, systemctl, loginctl, wl-copy, window-effect,
pw-play, toggle-shell) are stubs that log each call to $QS_TEST/calls. A fake Hyprland answers
queries with empty JSON (monitors with -m's file), logs each request (dispatches included) to
$QS_TEST/hyprland.log, and sends each line appended to $QS_TEST/events as an event,
for example: echo 'configreloaded>>' >>"$QS_TEST/events". The folder is kept.
EOF
}

config=$default_config
seconds=5
screens=1
monitors=
check=false
while [ $# -gt 0 ]; do
  case "$1" in
    -c) config=$2; shift 2 ;;
    -t) seconds=$2; shift 2 ;;
    -s) screens=$2; shift 2 ;;
    -m) monitors=$2; shift 2 ;;
    --check) check=true; shift ;;
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ ! -f "$config/shell.qml" ]; then
  echo "qs-test: no shell.qml in $config" >&2
  exit 2
fi

QS_TEST=$(mktemp -d "${TMPDIR:-/tmp}/qs-test.XXXXXX")
QS_CONFIG=$QS_TEST/config
export QS_TEST QS_CONFIG
mkdir -p "$QS_TEST/bin" "$QS_TEST/state/custom-shell" "$QS_TEST/cache" "$QS_TEST/data" "$QS_TEST/run" \
  "$QS_TEST/xdg-config/custom-shell"
chmod 700 "$QS_TEST/run"
# The user's fontconfig, so the shell finds the same fonts; nothing else of theirs.
user_config=${XDG_CONFIG_HOME:-$HOME/.config}
[ -d "$user_config/fontconfig" ] && ln -s "$user_config/fontconfig" "$QS_TEST/xdg-config/fontconfig"
: >"$QS_TEST/calls"
: >"$QS_TEST/events"
[ -n "$monitors" ] && cp "$monitors" "$QS_TEST/monitors.json"

# The shell as the rebuild installs it, shaders compiled.
cp -r "$config" "$QS_CONFIG"
chmod -R u+w "$QS_CONFIG"
compile_shaders "$QS_CONFIG"

# The saved wallpaper choice, so the shell does not ask for a new theme.
saved="${XDG_STATE_HOME:-$HOME/.local/state}/custom-shell/wallpaper.json"
[ -f "$saved" ] && cp "$saved" "$QS_TEST/state/custom-shell/"

for command in hyprctl generate-theme game-mode session-exit systemctl loginctl wl-copy window-effect toggle-shell pw-play; do
  cat >"$QS_TEST/bin/$command" <<EOF
#!/bin/sh
echo "$command \$*" >>"$QS_TEST/calls"
case " \$* " in *" -j "*) echo "[]" ;; esac
EOF
  chmod +x "$QS_TEST/bin/$command"
done

export PATH="$QS_TEST/bin:$PATH"
export XDG_RUNTIME_DIR=$QS_TEST/run XDG_STATE_HOME=$QS_TEST/state XDG_CONFIG_HOME=$QS_TEST/xdg-config
export XDG_CACHE_HOME=$QS_TEST/cache XDG_DATA_HOME=$QS_TEST/data
export HYPRLAND_INSTANCE_SIGNATURE=qs-test
export CUSTOM_SHELL_ALARM_SOUND=$alarm_sound
unset DISPLAY WAYLAND_DISPLAY

pids=()
stop() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done
  wait 2>/dev/null
}
trap stop EXIT

python3 -I "$fake_hyprland" "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE" "$QS_TEST/events" \
  "$QS_TEST/monitors.json" >"$QS_TEST/hyprland.log" 2>&1 &
pids+=($!)

# The package's own session config: the build sandbox has no /etc/dbus-1.
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
dbus-daemon --config-file="$dbus_config" --nofork --nopidfile --address="$DBUS_SESSION_BUS_ADDRESS" \
  >"$QS_TEST/dbus.log" 2>&1 &
pids+=($!)

: >"$QS_TEST/sway.conf"
for i in $(seq "$screens"); do
  printf 'output HEADLESS-%s resolution 1920x1080\n' "$i" >>"$QS_TEST/sway.conf"
done
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=$screens WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  "$sway" -c "$QS_TEST/sway.conf" >"$QS_TEST/sway.log" 2>&1 &
pids+=($!)
for _ in $(seq 100); do
  socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' -type s -printf '%f\n' | head -n 1)
  [ -n "$socket" ] && [ -S "$XDG_RUNTIME_DIR/bus" ] && break
  sleep 0.1
done
if [ -z "$socket" ]; then
  echo "qs-test: sway did not start; see $QS_TEST/sway.log" >&2
  exit 2
fi
if [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
  echo "qs-test: the session bus did not start; see $QS_TEST/dbus.log" >&2
  exit 2
fi
export WAYLAND_DISPLAY=$socket QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software

"$qs" -p "$QS_CONFIG" >"$QS_TEST/shell.log" 2>&1 &
shell=$!
pids+=("$shell")
loaded=false
for _ in $(seq 300); do
  if grep -q "Configuration Loaded" "$QS_TEST/shell.log"; then
    loaded=true
    break
  fi
  grep -q "Failed to load configuration" "$QS_TEST/shell.log" && break
  kill -0 "$shell" 2>/dev/null || break
  sleep 0.1
done

status=0
if $loaded; then
  if [ $# -gt 0 ]; then
    "$@"
    status=$?
  else
    sleep "$seconds"
  fi
fi
stop
trap - EXIT

# The shell's messages without colour codes; a QML error or warning names its file as
# @path/File.qml[line:column]. The shell's own console.warn and console.error (a check
# in shell.qml) log as "WARN qml:" and "ERROR qml:", with no file.
sed 's/\x1b\[[0-9;]*m//g' "$QS_TEST/shell.log" >"$QS_TEST/shell.txt"
qml_problems=$(grep -E 'Failed to load configuration|@[^ ]+\.qml\[|(WARN|ERROR) qml:' "$QS_TEST/shell.txt")

echo "== qs-test: $QS_TEST"
if $loaded; then echo "The shell loaded."; else echo "The shell did not load."; fi
if [ -n "$qml_problems" ]; then
  echo "== QML errors and warnings"
  echo "$qml_problems"
fi
echo "== Other warnings and errors (shell.txt has everything)"
grep -E 'WARN|ERROR' "$QS_TEST/shell.txt" | grep -vE '@[^ ]+\.qml\[|(WARN|ERROR) qml:' | sort | uniq -c | sort -rn | head -n 20
echo "== Stubbed calls (calls)"
cat "$QS_TEST/calls"

if $check && { ! $loaded || [ -n "$qml_problems" ]; }; then
  exit 1
fi
exit "$status"
