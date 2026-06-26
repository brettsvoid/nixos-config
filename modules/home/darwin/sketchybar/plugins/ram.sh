#!/usr/bin/env sh

# RAM in use, as a percentage. memory_pressure's final line reports free %:
#   "System-wide memory free percentage: 31%"
FREE=$(memory_pressure 2>/dev/null | awk -F: '/free percentage/ { gsub(/[ %]/, "", $2); print $2 }')
USED=$((100 - FREE))

sketchybar --set "$NAME" label="${USED}%"
