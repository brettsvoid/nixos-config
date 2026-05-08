#!/bin/bash

#DISK_INFO=$(df -h | grep 'disk1s1' | awk '{print $4}')
DISK_INFO=$(df -h | grep "/Data$" | awk '{print $4}' | sed 's/i//g')

# Remove the 'i' suffix (e.g., '500Gi' → '500G')
DISK_SPACE=${DISK_INFO%i}

# Output for SketchyBar
echo "$DISK_SPACE"

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" label="$DISK_SPACE"
