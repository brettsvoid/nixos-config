#!/bin/bash

#DISK_INFO=$(df -h | grep 'disk1s1' | awk '{print $4}')
DISK_INFO=$(df -h | grep "/Data$" | awk '{print $4}' | sed 's/i//g')

# Drop the 'i' suffix ('500Gi' → '500G'). Redundant: the sed above already
# removes it.
DISK_SPACE=${DISK_INFO%i}

echo "$DISK_SPACE"

# Set the invoking item's label to the free space.
sketchybar --set "$NAME" label="$DISK_SPACE"
