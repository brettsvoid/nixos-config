#!/usr/bin/env sh

# Swap currently in use, from the kernel's swap accounting:
#   sysctl -n vm.swapusage
#   -> "total = 12288.00M  used = 11224.94M  free = 1063.06M  (encrypted)"
USED_MB=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/')

# Show GB past 1024 MB, otherwise MB; whole-ish numbers to stay narrow.
LABEL=$(awk -v m="$USED_MB" 'BEGIN {
  if (m + 0 >= 1024) printf "%.1fG", m / 1024
  else              printf "%.0fM", m
}')

sketchybar --set "$NAME" label="$LABEL"
