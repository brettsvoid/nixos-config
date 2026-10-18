#!/usr/bin/env bash
# window-dissolve issue 05: what HyprWindowShade costs a running game. MangoHud logs the
# same scene with the plugin loaded, unloaded, then loaded again, and Hyprland's own CPU
# time is read over each phase. A table of the results is printed and saved.
#
# Usage: bash .scratch/window-dissolve/measure-game-cost.sh [-s SECONDS] [--popups] LABEL
#   LABEL      names the run, for example fullscreen or windowed.
#   -s         seconds per phase (default 60).
#   --popups   adds two phases in which a small window opens over the game and closes
#              again every 5 seconds, with the plugin loaded and then unloaded (question
#              4 in the issue).
#
# Start the game and stand somewhere quiet, then run this. In the game, press Left
# Shift+F2 (MangoHud's log key) and keep still. The phases start once the log appears,
# and a notification says when they are done; press Left Shift+F2 again then to stop the
# log. The plugin is loaded again at the end, also after Ctrl+C.
#
# One log covers the whole run and is split into phases by its elapsed column. MangoHud's
# control socket can't start the logs: each Vulkan instance tries to listen on it, only
# the first in a process gets it, and an instance answers it only while it presents.
# Proton games make several instances, and the socket went unanswered with The Crust.
set -u

seconds=60
popups=false
label=""
while [ $# -gt 0 ]; do
  case "$1" in
    -s) seconds=$2; shift 2 ;;
    --popups) popups=true; shift ;;
    -h | --help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

hypr_pid=$(hyprctl -j instances | jq -r --arg sig "${HYPRLAND_INSTANCE_SIGNATURE:-}" '.[] | select(.instance == $sig) | .pid')
ticks=$(getconf CLK_TCK)

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

notify() {
  command -v notify-send >/dev/null && notify-send -a "Dissolve cost" "$1" "$2" || true
}

# Hyprland's CPU time so far, in clock ticks (user plus system).
hypr_ticks() {
  awk '{ print $14 + $15 }' "/proc/$hypr_pid/stat"
}

# A small window, opened over the game without taking focus, closing after 2 seconds.
popup() {
  hyprctl dispatch exec "[float on; size 480 270; move 40 40; no_initial_focus on] kitty --class dissolve-probe sh -c 'sleep 2'" >/dev/null
}

# The log's position now: the elapsed column (nanoseconds since the log started) of its
# last complete row, or -1 before the first. MangoHud writes a row per frame as it goes.
log_now() {
  python3 -I -c '
import os, sys
path = sys.argv[1]
with open(path) as f:
    width = len([next(f) for _ in range(3)][2].split(","))
with open(path, "rb") as f:
    f.seek(max(0, os.path.getsize(path) - 16384))
    lines = f.read().decode(errors="replace").split("\n")[:-1]
for line in reversed(lines):
    fields = line.split(",")
    if len(fields) == width and fields[-1].isdigit():
        print(fields[-1])
        break
else:
    print(-1)
' "$log" 2>/dev/null || echo -1
}

# A phase's figures from the rows of MangoHud's log between two positions, as
# comma-separated values: average FPS, 1% and 0.1% lows (from the 99th and 99.9th
# percentile frame times), the worst frame, frames over twice the median, GPU load, VRAM,
# and frames dropped as impossible. MangoHud sometimes logs a single frame of over an
# hour, which would wreck its own averages; frames over 10 seconds are left out and
# counted.
stats() {
  python3 -I -c '
import csv, statistics, sys
lines = open(sys.argv[1]).read().split("\n")[:-1]
rows = list(csv.reader(lines))
header = rows[2]
start, end = int(sys.argv[2]), int(sys.argv[3])
data = [dict(zip(header, r)) for r in rows[3:] if len(r) == len(header)]
data = [r for r in data if r["elapsed"].isdigit() and start < int(r["elapsed"]) <= end]
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
' "$log" "$1" "$2"
}

rows=()
phase() {
  local name=$1 start_ticks end_ticks start_ns end_ns start took cpu
  echo "== $name: $seconds s"
  sleep 3
  start_ns=$(log_now)
  start_ticks=$(hypr_ticks)
  start=$SECONDS
  if [[ $name == popups* ]]; then
    while [ $((SECONDS - start)) -lt "$seconds" ]; do
      popup
      sleep "$(( seconds - (SECONDS - start) < 5 ? seconds - (SECONDS - start) : 5 ))"
    done
  else
    sleep "$seconds"
  fi
  end_ticks=$(hypr_ticks)
  end_ns=$(log_now)
  took=$((SECONDS - start))
  if [ "$end_ns" -le "$start_ns" ]; then
    echo "MangoHud's log stopped during $name (was Left Shift+F2 pressed again, or has the game exited?)" >&2
    notify "Measurement stopped" "MangoHud's log stopped during $name."
    exit 1
  fi
  cpu=$(awk -v d="$((end_ticks - start_ticks))" -v t="$ticks" -v s="$took" 'BEGIN { printf "%.1f", d / t / (s > 0 ? s : 1) * 100 }')
  rows+=("$name,$(stats "$start_ns" "$end_ns"),$cpu")
}

# Wait for the log that Left Shift+F2 starts: a CSV that wasn't there before.
csvs() {
  find "$logs" -maxdepth 1 -name '*.csv' ! -name '*_summary.csv' | sort
}
old=$(csvs)
echo "Plugin: $plugin. Logs: $logs"
echo "Phases of $seconds s: loaded, unloaded, loaded$($popups && echo ', popups loaded, popups unloaded')."
echo "In the game, press Left Shift+F2 to start MangoHud's log, then keep still."
log=""
for _ in $(seq 1200); do
  log=$(comm -13 <(echo "$old") <(csvs) | tail -n 1)
  [ -n "$log" ] && [ "$(log_now)" -ge 0 ] && break
  sleep 0.5
done
if [ -z "$log" ] || [ "$(log_now)" -lt 0 ]; then
  echo "No MangoHud log started within 10 minutes." >&2
  exit 1
fi
# The log is named <program>_<date>_<time>.csv.
game=$(basename "$log" .csv)
game=${game%_*_*}
echo "Logging $game to $log"

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
load || echo "Could not load the plugin again: hyprctl plugin load $plugin" >&2
notify "Measurement done" "Press Left Shift+F2 to stop MangoHud's log."

result=$logs/dissolve-cost-$label-$(date +%F_%H-%M-%S).txt
{
  echo "HyprWindowShade's cost: $label, $game, $seconds s per phase, $(date '+%F %H:%M')"
  echo "Log: $(basename "$log")"
  echo
  {
    echo "phase,avg fps,1% low,0.1% low,worst ms,hitches,GPU %,VRAM GiB,dropped,Hyprland CPU %"
    printf '%s\n' "${rows[@]}"
  } | column -t -s,
} | tee "$result"
echo
echo "Saved to $result."
echo "Hitches are frames over twice the phase's median frame time. Dropped are frames MangoHud"
echo "logged as over 10 s, left out of the rest. Hyprland CPU % is of one core."
echo "Press Left Shift+F2 in the game to stop MangoHud's log, if it is still running."
