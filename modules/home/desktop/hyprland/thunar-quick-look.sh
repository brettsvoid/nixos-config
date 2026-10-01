# Space in Thunar runs this for the selection: it is the command of
# Thunar's Quick Look custom action (home/desktop/hyprland.nix). It
# previews the file in Sushi; Space again on the same file closes it.
state="$XDG_RUNTIME_DIR/thunar-quick-look"
mkdir -p "$state"

# thunar-quick-look-keys pressed Space for an arrow key in the preview.
# Keep the preview open even when Thunar's selection did not move (at the
# first or last file). A flag older than 2 s is from a Space that Thunar
# never acted on, and must not affect this one.
follow="$state/follow"
if [ -e "$follow" ] && [ $(($(date +%s) - $(stat -c %Y "$follow"))) -le 2 ]; then
  rm -f "$follow"
  SUSHI_FOLLOW=1 exec sushi "$1"
fi
rm -f "$follow"

# Remember the Thunar window that asked, for thunar-quick-look-keys.
window=$(hyprctl activewindow -j | jq -r 'select(.class == "thunar") | .address') || true
if [ -n "$window" ]; then
  echo "$window" >"$state/window"
fi

exec sushi "$1"
