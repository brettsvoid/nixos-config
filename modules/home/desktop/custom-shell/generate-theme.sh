# generate-theme [image] [--scheme X] [--mode light|dark | --light | --dark]: sets the
# wallpaper and generates the shell's theme from it with matugen. Anything not given
# comes from the saved choice; with no saved image, the first in ~/Pictures/Wallpapers.
# The choice is kept in ~/.local/state/custom-shell/wallpaper.json, which the shell
# watches to show the image; the colours go to ~/.cache/qs-theme/colors.json. Paths are
# kept as given, so a ~/Pictures/Wallpapers link stays valid across rebuilds where the
# store path behind it would not.
# custom-shell.nix puts before this: $matugen_config, and $theme_apps (true where the
# shell's theme is the desktop's, so GTK follows it too).
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/custom-shell"
STATE="$STATE_DIR/wallpaper.json"
# Where the choice lived before, as a store path that a rebuild leaves stale.
OLD_STATE="$HOME/.cache/qs-theme/wallpaper.json"
WALLPAPERS="$HOME/Pictures/Wallpapers"
mkdir -p "$STATE_DIR" "$HOME/.cache/qs-theme"

WALLPAPER=""
SCHEME=""
MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --dark) MODE="dark"; shift ;;
    --light) MODE="light"; shift ;;
    -h|--help)
      echo "Usage: generate-theme [image] [--scheme X] [--mode light|dark]"
      echo "Schemes: scheme-neutral, scheme-tonal-spot, scheme-content, scheme-fidelity,"
      echo "         scheme-expressive, scheme-fruit-salad, scheme-monochrome, scheme-rainbow"
      exit 0 ;;
    *) WALLPAPER="$1"; shift ;;
  esac
done

if [ -f "$STATE" ]; then
  [ -z "$WALLPAPER" ] && WALLPAPER=$(jq -r '.path // empty' "$STATE")
  [ -z "$SCHEME" ] && SCHEME=$(jq -r '.scheme // empty' "$STATE")
  [ -z "$MODE" ] && MODE=$(jq -r '.mode // empty' "$STATE")
elif [ -f "$OLD_STATE" ]; then
  [ -z "$SCHEME" ] && SCHEME=$(jq -r '.scheme // empty' "$OLD_STATE")
  [ -z "$MODE" ] && MODE=$(jq -r '.mode // empty' "$OLD_STATE")
  if [ -z "$WALLPAPER" ]; then
    NAME=$(basename "$(jq -r '.currentWall // empty' "$OLD_STATE")")
    [ -n "$NAME" ] && [ -e "$WALLPAPERS/$NAME" ] && WALLPAPER="$WALLPAPERS/$NAME"
  fi
fi
if [ -z "$WALLPAPER" ] || [ ! -e "$WALLPAPER" ]; then
  WALLPAPER=$(find -L "$WALLPAPERS" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1)
fi
if [ -z "$WALLPAPER" ]; then
  echo "No wallpaper: give an image, or put some in $WALLPAPERS" >&2
  exit 1
fi
case "$WALLPAPER" in
  /*) ;;
  *) WALLPAPER="$PWD/$WALLPAPER" ;;
esac
SCHEME="${SCHEME:-scheme-neutral}"
MODE="${MODE:-light}"

# The choice first, so the shell starts loading the image while matugen runs.
jq -n --arg path "$WALLPAPER" --arg scheme "$SCHEME" --arg mode "$MODE" \
  '{path: $path, scheme: $scheme, mode: $mode}' >"$STATE.tmp"
mv "$STATE.tmp" "$STATE"

echo "Generating theme: $WALLPAPER (scheme: $SCHEME, mode: $MODE)"
if ! matugen image "$WALLPAPER" \
  --source-color-index 0 \
  -c "$matugen_config" \
  -t "$SCHEME" \
  -m "$MODE"; then
  echo "matugen failed — theme not generated" >&2
  exit 1
fi

# GTK 3's theme in the mode's variant, and the light or dark preference that libadwaita
# apps and Firefox follow, both where the settings portal reads them. Both apply to
# open apps at once.
if [ "$theme_apps" = true ]; then
  theme=adw-gtk3
  [ "$MODE" = dark ] && theme=adw-gtk3-dark
  if ! dconf write /org/gnome/desktop/interface/gtk-theme "'$theme'" \
    || ! dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$MODE'"; then
    echo "Could not set GTK's theme and light or dark preference in dconf" >&2
  fi
fi
