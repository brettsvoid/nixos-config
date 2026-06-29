# Select a desktop wallpaper from ~/Pictures/Wallpapers. With no argument it
# prints an interactive numbered menu; with an argument it picks by number or by
# filename substring (e.g. `select-wallpaper rem`). The launchd watcher
# (edgebar.nix) re-themes edgebar from the chosen wallpaper.
wall_dir="$HOME/Pictures/Wallpapers"
cd "$wall_dir" || exit 1
shopt -s nullglob
files=(*.jpg *.jpeg *.png *.webp)
if [ "${#files[@]}" -eq 0 ]; then
  echo "no wallpapers in $wall_dir" >&2
  exit 1
fi

set_wall() {
  desktoppr all "$wall_dir/$1" >/dev/null
  echo "wallpaper → $1"
}

# Direct selection: number (1-based) or filename substring.
if [ "$#" -gt 0 ]; then
  arg="$1"
  if [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -ge 1 ] && [ "$arg" -le "${#files[@]}" ]; then
    set_wall "${files[$((arg - 1))]}"
    exit 0
  fi
  for f in "${files[@]}"; do
    if [[ "$f" == *"$arg"* ]]; then
      set_wall "$f"
      exit 0
    fi
  done
  echo "no wallpaper matching '$arg'" >&2
  exit 1
fi

# Interactive menu.
PS3="Select wallpaper (number): "
select pick in "${files[@]}"; do
  if [ -n "$pick" ]; then
    set_wall "$pick"
    break
  fi
done
