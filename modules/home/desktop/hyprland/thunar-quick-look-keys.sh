# Left, Right, Up and Down in Sushi's preview ask the file manager to move
# its selection: Sushi emits SelectionEvent on D-Bus, which Nautilus acts
# on and Thunar ignores. This acts on it for Thunar. It sends the arrow key
# to the Thunar window the preview came from (thunar-quick-look records
# it), so Thunar moves its selection through its own grid or list, then
# Space, which previews the new selection.
state="$XDG_RUNTIME_DIR/thunar-quick-look"

gdbus monitor --session --dest org.gnome.NautilusPreviewer \
  --object-path /org/gnome/NautilusPreviewer |
  while read -r line; do
    # The argument is a GtkDirectionType.
    case $line in
    *'.SelectionEvent (uint32 2,)') key=Up ;;
    *'.SelectionEvent (uint32 3,)') key=Down ;;
    *'.SelectionEvent (uint32 4,)') key=Left ;;
    *'.SelectionEvent (uint32 5,)') key=Right ;;
    *) continue ;;
    esac

    window=$(cat "$state/window" 2>/dev/null) || continue
    hyprctl dispatch sendshortcut ", $key, address:$window" >/dev/null || continue
    touch "$state/follow"
    hyprctl dispatch sendshortcut ", space, address:$window" >/dev/null || true
  done
