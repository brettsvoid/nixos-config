#!/bin/sh
#
# Catppuccin colour palette for SketchyBar.
#
# Layered so there's a single source of truth:
#   1. Raw palette  — the canonical Catppuccin colours, opaque (0xff…).
#   2. Surfaces     — base tints, some pre-alpha'd for translucent backgrounds.
#   3. Semantic roles (COLOR_*) — what sketchybarrc and the plugins reference.
#      Accents and backgrounds carry an 0xe0 alpha (~88%) so brackets stay
#      slightly translucent, matching the original look.
#
# Previously this file paired a Gruvbox accent set (mislabelled "Catpuccin")
# with a Catppuccin base. It is now Catppuccin throughout.

# ── Raw palette (opaque) ────────────────────────────────────────────────────
export RED=0xffed8796
export MAROON=0xffee99a0
export PEACH=0xfff5a97f
export YELLOW=0xffeed49f
export GREEN=0xffa6da95
export TEAL=0xff8bd5ca
export SKY=0xff91d7e3
export BLUE=0xff8aadf4
export MAUVE=0xffc6a0f6
export PINK=0xfff5bde6
export FLAMINGO=0xfff0c6c6
export LAVENDER=0xffb7bdf8
export WHITE=0xffcad3f5
export GREY=0xff939ab7
export BLACK=0xff181926
export ORANGE=$PEACH
export MAGENTA=$MAUVE
export CYAN=$TEAL
export TRANSPARENT=0x00000000

# ── Surfaces ────────────────────────────────────────────────────────────────
# Base (0xff1e1e2e) at varying opacity, plus two translucent panel tints.
export BG0=0xff1e1e2e
export BG0O50=0x801e1e2e
export BG0O60=0x991e1e2e
export BG0O70=0xB21e1e2e
export BG0O80=0xCC1e1e2e
export BG0O85=0xD91e1e2e
export BG1=0x603c3e4f
export BG2=0x60494d64

# ── Semantic roles ──────────────────────────────────────────────────────────
# Accents, translucent (0xe0) to preserve the original bracket appearance.
export COLOR_RED=0xe0ed8796
export COLOR_GREEN=0xe0a6da95
export COLOR_YELLOW=0xe0eed49f
export COLOR_BLUE=0xe08aadf4
export COLOR_MAGENTA=0xe0c6a0f6
export COLOR_CYAN=0xe08bd5ca
export COLOR_WHITE=0xe0cad3f5
export COLOR_ORANGE=0xfff5a97f

# "Bright" accents — Catppuccin has one shade per hue, so these track the base
# accent (a touch lighter for red, via maroon) for the battery/volume states.
export COLOR_RED_BRIGHT=0xe0ee99a0
export COLOR_GREEN_BRIGHT=0xe0a6da95
export COLOR_YELLOW_BRIGHT=0xe0eed49f
export COLOR_MAGENTA_BRIGHT=0xe0c6a0f6

# Chrome
export COLOR_BACKGROUND=0xe01e1e2e
export COLOR_TRANSPARENT=0x00000000
export COLOR_BORDER=$COLOR_YELLOW
export COLOR_ICON=$COLOR_YELLOW
export COLOR_LABEL=$COLOR_YELLOW
export COLOR_DATE_TIME=$COLOR_RED

# Bar chrome (referenced by sketchybarrc's appearance block)
export BAR_COLOR=$BG0O85
export BAR_BORDER_COLOR=$BG2
export BACKGROUND_1=$BG1
export BACKGROUND_2=$BG2
export ICON_COLOR=$WHITE
export LABEL_COLOR=$WHITE
export POPUP_BACKGROUND_COLOR=$BAR_COLOR
export POPUP_BORDER_COLOR=$WHITE
export SHADOW_COLOR=$BLACK
