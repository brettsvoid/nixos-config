#!/bin/sh

# front_app_switched passes the newly focused app's name in $INFO:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting
#
# Prefer a sketchybar-app-font glyph (installed by fonts.nix) looked up via
# icon_map.sh. For apps it doesn't know it returns ":default:", and we show the
# real macOS app icon instead (SketchyBar's "app.<name>" image).

if [ "$SENDER" = "front_app_switched" ]; then
  GLYPH=$("$CONFIG_DIR/plugins/icon_map.sh" "$INFO")

  if [ "$GLYPH" = ":default:" ]; then
    sketchybar --set "$NAME" label="$INFO" \
                            icon="" \
                            icon.background.image="app.$INFO" \
                            icon.background.drawing=on
  else
    sketchybar --set "$NAME" label="$INFO" \
                            icon="$GLYPH" \
                            icon.background.drawing=off
  fi
fi
