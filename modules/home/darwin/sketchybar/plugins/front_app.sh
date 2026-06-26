#!/bin/sh

# The front_app_switched event sends the newly focused app's name in $INFO:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting
#
# Icon strategy: prefer a glyph from the sketchybar-app-font (installed via
# fonts.nix) by mapping the app name through icon_map.sh. icon_map returns
# ":default:" for apps it doesn't know — in that case we fall back to the real
# macOS app icon, which SketchyBar renders from the "app.<name>" image value.

if [ "$SENDER" = "front_app_switched" ]; then
  GLYPH=$("$CONFIG_DIR/plugins/icon_map.sh" "$INFO")

  if [ "$GLYPH" = ":default:" ]; then
    # No mapped glyph — show the application's own icon image.
    sketchybar --set "$NAME" label="$INFO" \
                            icon="" \
                            icon.background.image="app.$INFO" \
                            icon.background.drawing=on
  else
    # Mapped glyph from the app font.
    sketchybar --set "$NAME" label="$INFO" \
                            icon="$GLYPH" \
                            icon.background.drawing=off
  fi
fi
