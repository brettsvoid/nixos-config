#!/usr/bin/env bash
# measure-steam.sh <label> [seconds]: Steam's GPU, VRAM, RAM and CPU use over a window.
# Steam is every process under the oldest steam.sh. GPU use is nvidia-smi pmon's SM%
# per pid, sampled each second; VRAM is the nvidia-smi process table at the end.
set -u
label=$1
secs=${2:-30}

root=$(pgrep -o -f 'Steam/steam.sh')
[ -n "$root" ] || { echo "$label: Steam is not running"; exit 1; }

tree() {
  ps -e -o pid=,ppid= | awk -v r="$root" '
    { kids[$2] = kids[$2] " " $1 }
    END {
      n = split(r, q, " ")
      while (n > 0) {
        p = q[n--]; print p
        m = split(kids[p], k, " ")
        for (i = 1; i <= m; i++) q[++n] = k[i]
      }
    }'
}

ticks() {
  local sum=0 t
  for p in $(tree); do
    t=$(awk '{print $14 + $15}' "/proc/$p/stat" 2>/dev/null) && sum=$((sum + t))
  done
  echo "$sum"
}

pids=" $(tree | tr '\n' ' ') "
c0=$(ticks)
pmon=$(nvidia-smi pmon -s u -d 1 -c "$secs" 2>/dev/null)
c1=$(ticks)

# SM% per Steam pid, averaged over the samples ("-" counts as 0).
sm=$(echo "$pmon" | awk -v pids="$pids" -v n="$secs" '
  !/^#/ && index(pids, " " $2 " ") { v = ($4 == "-") ? 0 : $4; s[$2] += v; name[$2] = $NF }
  END { for (p in s) printf "%s(%s) %.1f%%  ", name[p], p, s[p] / n }')

vram=$(nvidia-smi | awk -v pids="$pids" '
  /MiB \|$/ && $5 ~ /^[0-9]+$/ && index(pids, " " $5 " ") {
    m = $(NF - 1); sub("MiB", "", m); total += m; parts = parts sprintf("%s=%s ", $5, m)
  }
  END { printf "%d MiB (%s)", total, parts }')

pss=0
for p in $(tree); do
  k=$(awk '/^Pss:/ {print $2}' "/proc/$p/smaps_rollup" 2>/dev/null) && pss=$((pss + k))
done

echo "$label"
echo "  VRAM:  $vram"
echo "  GPU:   ${sm:-no Steam process used the GPU}"
echo "  CPU:   $(( (c1 - c0) * 100 / secs / $(getconf CLK_TCK) ))% of one core over ${secs} s"
echo "  RAM:   $((pss / 1024)) MiB PSS across $(tree | wc -l) processes"
