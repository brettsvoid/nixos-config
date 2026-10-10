#!/usr/bin/env sh

# sketchybar passes the invoking item's name in $NAME:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

sketchybar --set $NAME label="$(date '+%a %d %b')"
