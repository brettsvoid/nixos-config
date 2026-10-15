# wallpaper-thumbnails [folder]: thumbnails for the wallpaper picker, made once per
# image. The picker gives the settings' wallpaper folder. <folder>/<name> becomes
# ~/.cache/custom-shell/wallpaper-thumbnails/<name>.<size in bytes>.jpg, so an image
# replaced under the same name gets a new one. Written under a temporary name and moved
# into place, so the picker never shows half a file.
SRC="${1:-$HOME/Pictures/Wallpapers}"
OUT="${XDG_CACHE_HOME:-$HOME/.cache}/custom-shell/wallpaper-thumbnails"
mkdir -p "$OUT"
# The picker starts watching the folder on this line, so it must exist first.
echo ready
for f in "$SRC"/*; do
  [ -f "$f" ] || continue
  case "${f,,}" in
    *.jpg | *.jpeg | *.png | *.webp) ;;
    *) continue ;;
  esac
  thumb="$OUT/$(basename "$f").$(stat -L -c %s "$f").jpg"
  [ -e "$thumb" ] && continue
  # The temporary name must not end in .jpg: the picker only sees a thumbnail arrive
  # when the number of .jpg files changes, which a rename does not do.
  magick "${f}[0]" -auto-orient -thumbnail '384x216^' \
    -gravity center -extent 384x216 -quality 85 "jpg:$thumb.part" \
    && mv "$thumb.part" "$thumb"
done
