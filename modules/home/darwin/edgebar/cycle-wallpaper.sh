# Advance the desktop wallpaper to the next image in ~/Pictures/Wallpapers
# (wrapping around). The launchd watcher (edgebar.nix) re-themes edgebar from the
# new wallpaper, so the bar follows within ~1s. `desktoppr` is on PATH via
# writeShellApplication's runtimeInputs.
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
