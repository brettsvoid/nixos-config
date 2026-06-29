# Advance the desktop wallpaper to the next image in ~/Pictures/Wallpapers
# (wrapping around), then re-theme edgebar directly so the bar follows instantly.
# (The launchd watcher in edgebar.nix still handles wallpaper changes made
# OUTSIDE edgebar, e.g. via System Settings.) `desktoppr` and
# `generate-edgebar-theme` are on PATH via writeShellApplication's runtimeInputs.
wall_dir="$HOME/Pictures/Wallpapers"
cd "$wall_dir" || exit 1
shopt -s nullglob
files=(*.jpg *.jpeg *.png *.webp)
if [ "${#files[@]}" -eq 0 ]; then
  echo "no wallpapers in $wall_dir" >&2
  exit 1
fi

# Current wallpaper (first display); basename to match against the dir listing.
mapfile -t cur < <(desktoppr)
current_base="$(basename "${cur[0]:-}")"

idx=-1
for i in "${!files[@]}"; do
  if [ "${files[$i]}" = "$current_base" ]; then
    idx=$i
    break
  fi
done

next=$(((idx + 1) % ${#files[@]}))
pick="${files[$next]}"
desktoppr all "$wall_dir/$pick" >/dev/null
echo "wallpaper → $pick"
generate-edgebar-theme "$wall_dir/$pick"
