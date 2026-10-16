#!/usr/bin/env bash
# window-dissolve issue 05: what HyprWindowShade costs a running game. MangoHud logs the
# same scene with the plugin loaded, unloaded, then loaded again, and Hyprland's own CPU
# time is read over each phase. A table of the results is printed and saved.
#
# Usage: bash .scratch/window-dissolve/measure-game-cost.sh [-s SECONDS] [-p PID] [--popups] LABEL
#   LABEL      names the run, for example fullscreen or windowed.
#   -s         seconds per phase (default 60).
#   -p         the game's pid, when more than one program has MangoHud loaded.
#   --popups   adds two phases in which a small window opens over the game and closes
#              again every 5 seconds, with the plugin loaded and then unloaded (question
#              4 in the issue).
#
# Start the game and stand somewhere quiet. Run this from a terminal on the other screen,
# go back to the game during the countdown, and keep still until it says it is done.
# The plugin is loaded again at the end, also after Ctrl+C.
#
# It needs MangoHud's control socket (control = "mangohud-%p" in
# modules/profiles/gaming.nix): start the game after a rebuild that has it.
set -u

seconds=60
pid=""
popups=false
label=""
while [ $# -gt 0 ]; do
  case "$1" in
    -s) seconds=$2; shift 2 ;;
    -p) pid=$2; shift 2 ;;
    --popups) popups=true; shift ;;
    -h | --help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option $1 (--help)" >&2; exit 2 ;;
    *) label=$1; shift ;;
  esac
done
if [ -z "$label" ]; then
  echo "Give the run a label, for example fullscreen or windowed (--help)" >&2
  exit 2
fi

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
# The plugin's library, from the line in Hyprland's config that loads it.
plugin=${WINDOWSHADE_PLUGIN:-$(grep -o -m 1 '/nix/store/[^ ]*libhyprwindowshade\.so' "$config_home/hypr/hyprland.conf" 2>/dev/null)}
if [ -z "$plugin" ] || [ ! -f "$plugin" ]; then
  echo "Could not find libhyprwindowshade.so in $config_home/hypr/hyprland.conf" >&2
  exit 1
fi
# Where MangoHud writes its logs.
logs=$(sed -n 's/^output_folder=//p' "$config_home/MangoHud/MangoHud.conf" 2>/dev/null | tail -n 1)
logs=${logs:-$HOME}

# The programs with MangoHud's control socket open (@mangohud-<pid>).
mapfile -t sockets < <(grep -o '@mangohud-[0-9]*$' /proc/net/unix | sort -u | sed 's/^@mangohud-//')
if [ -z "$pid" ]; then
  if [ "${#sockets[@]}" -eq 1 ]; then
    pid=${sockets[0]}
  elif [ "${#sockets[@]}" -eq 0 ]; then
    echo "No program has MangoHud's control socket open. Is the game running, and was it" >&2
    echo "started after a rebuild with control = \"mangohud-%p\"?" >&2
    exit 1
  else
    echo "More than one program has MangoHud loaded; choose one with -p:" >&2
    for p in "${sockets[@]}"; do echo "  $p  $(cat "/proc/$p/comm" 2>/dev/null)" >&2; done
    exit 1
  fi
fi
game=$(cat "/proc/$pid/comm" 2>/dev/null || echo "pid $pid")

hypr_pid=$(hyprctl -j instances | jq -r --arg sig "${HYPRLAND_INSTANCE_SIGNATURE:-}" '.[] | select(.instance == $sig) | .pid')
ticks=$(getconf CLK_TCK)

# Sends a command to the game's MangoHud: logging=1 starts a log, logging=0 stops it.
mangohud() {
  python3 -I -c '
import socket, sys, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("\0mangohud-" + sys.argv[1])
s.settimeout(2)
try:
    s.recv(4096)
except OSError:
    pass
s.sendall((":" + sys.argv[2] + ";").encode())
time.sleep(0.5)
s.close()
' "$pid" "$1"
}

loaded() {
  hyprctl -j plugin list 2>/dev/null | jq -e 'any(.[]?; .name == "HyprWindowShade")' >/dev/null 2>&1
}
load() {
  loaded && return 0
  hyprctl plugin load "$plugin" >/dev/null
  loaded
}
unload() {
  loaded || return 0
  hyprctl plugin unload "$plugin" >/dev/null
  ! loaded
}
finish() {
  if ! loaded; then
    if load; then echo "The plugin is loaded again."; else echo "Could not load the plugin again: hyprctl plugin load $plugin" >&2; fi
  fi
}
trap finish EXIT
trap 'exit 130' INT TERM

# Hyprland's CPU time so far, in clock ticks (user plus system).
hypr_ticks() {
  awk '{ print $14 + $15 }' "/proc/$hypr_pid/stat"
}

# A small window, opened over the game without taking focus, closing after 2 seconds.
popup() {
  hyprctl dispatch exec "[float on; size 480 270; move 40 40; no_initial_focus on] kitty --class dissolve-probe sh -c 'sleep 2'" >/dev/null
}

# A phase's figures from MangoHud's log (one row per frame), as comma-separated values:
# average FPS, 1% and 0.1% lows (from the 99th and 99.9th percentile frame times), the
# worst frame, frames over twice the median, GPU load, VRAM, and frames dropped as
# impossible. MangoHud sometimes logs a single frame of over an hour, which would wreck
# its own averages; frames over 10 seconds are left out and counted.
stats() {
  python3 -I -c '
import csv, statistics, sys
rows = list(csv.reader(open(sys.argv[1])))
header = rows[2]
data = [dict(zip(header, r)) for r in rows[3:] if len(r) == len(header)]
times = [float(r["frametime"]) for r in data]
kept = sorted(t for t in times if t < 10000)
if not kept:
    print(",,,,,,,%d" % len(times))
    sys.exit()
def pct(p):
    return kept[min(len(kept) - 1, int(len(kept) * p))]
median = statistics.median(kept)
gpu = statistics.mean(float(r["gpu_load"]) for r in data)
vram = statistics.mean(float(r["gpu_vram_used"]) for r in data)
print("%.1f,%.1f,%.1f,%.1f,%d,%.0f,%.2f,%d" % (
    1000 * len(kept) / sum(kept), 1000 / pct(0.99), 1000 / pct(0.999), kept[-1],
    sum(1 for t in kept if t > 2 * median), gpu, vram, len(times) - len(kept)))
' "$1"
}

rows=()
phase() {
  local name=$1 start_ticks end_ticks log before start
  echo "== $name: $seconds s"
  sleep 3
  before=$(date +%s)
  start_ticks=$(hypr_ticks)
  mangohud logging=1
  start=$SECONDS
  if [[ $name == popups* ]]; then
    while [ $((SECONDS - start)) -lt "$seconds" ]; do
      popup
      sleep "$(( seconds - (SECONDS - start) < 5 ? seconds - (SECONDS - start) : 5 ))"
    done
  else
    sleep "$seconds"
  fi
  mangohud logging=0
  end_ticks=$(hypr_ticks)
  local took=$((SECONDS - start))
  sleep 2
  log=$(find "$logs" -maxdepth 1 -name '*.csv' ! -name '*_summary.csv' -newermt "@$before" -printf '%T@ %p\n' | sort -n | tail -n 1 | cut -d' ' -f2-)
  if [ -z "$log" ]; then
    echo "MangoHud wrote no log for $name (is $logs its output_folder?)" >&2
    rows+=("$name,,,,,,,,,,")
    return
  fi
  local cpu
  cpu=$(awk -v d="$((end_ticks - start_ticks))" -v t="$ticks" -v s="$took" 'BEGIN { printf "%.1f", d / t / (s > 0 ? s : 1) * 100 }')
  rows+=("$name,$(stats "$log"),$cpu,$(basename "$log")")
}

echo "Game: $game (pid $pid). Plugin: $plugin"
echo "Phases of $seconds s: loaded, unloaded, loaded$($popups && echo ', popups loaded, popups unloaded'). Logs: $logs"
for n in 10 9 8 7 6 5 4 3 2 1; do printf '\rStarting in %2d s: go back to the game and keep still ' "$n"; sleep 1; done
echo

load || { echo "Could not load the plugin" >&2; exit 1; }
phase loaded
unload || { echo "Could not unload the plugin" >&2; exit 1; }
phase unloaded
load || { echo "Could not load the plugin again" >&2; exit 1; }
phase loaded-again
if $popups; then
  phase popups
  unload || { echo "Could not unload the plugin" >&2; exit 1; }
  phase popups-unloaded
fi

result=$logs/dissolve-cost-$label-$(date +%F_%H-%M-%S).txt
{
  echo "HyprWindowShade's cost: $label, $game, $seconds s per phase, $(date '+%F %H:%M')"
  echo
  {
    echo "phase,avg fps,1% low,0.1% low,worst ms,hitches,GPU %,VRAM GiB,dropped,Hyprland CPU %,log"
    printf '%s\n' "${rows[@]}"
  } | column -t -s,
} | tee "$result"
echo
echo "Saved to $result."
echo "Hitches are frames over twice the phase's median frame time. Dropped are frames MangoHud"
echo "logged as over 10 s, left out of the rest. Hyprland CPU % is of one core."
