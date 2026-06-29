# Select the matugen scheme type edgebar derives its palette with. Persists the
# choice to ~/.config/edgebar/scheme (so the launchd watcher's auto re-themes use
# it too) and immediately re-themes the current wallpaper.
#
#   select-scheme                 # interactive menu
#   select-scheme vibrant         # by name (with or without the scheme- prefix)
#   select-scheme 2               # by number
#
# `generate-edgebar-theme` is on PATH via writeShellApplication's runtimeInputs.
schemes=(
  scheme-tonal-spot
  scheme-vibrant
  scheme-expressive
  scheme-content
  scheme-fidelity
  scheme-neutral
  scheme-monochrome
  scheme-rainbow
  scheme-fruit-salad
)
state="$HOME/.config/edgebar/scheme"

apply() {
  mkdir -p "$(dirname "$state")"
  echo "$1" >"$state"
  echo "scheme → $1 (re-theming current wallpaper…)"
  generate-edgebar-theme
}

if [ "$#" -gt 0 ]; then
  arg="$1"
  if [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -ge 1 ] && [ "$arg" -le "${#schemes[@]}" ]; then
    apply "${schemes[$((arg - 1))]}"
    exit 0
  fi
  for s in "${schemes[@]}"; do
    if [ "$s" = "$arg" ] || [ "$s" = "scheme-$arg" ] || [[ "$s" == *"$arg"* ]]; then
      apply "$s"
      exit 0
    fi
  done
  echo "unknown scheme '$arg'. options: ${schemes[*]}" >&2
  exit 1
fi

# Interactive menu — mark the currently-active scheme with a star.
current="$(cat "$state" 2>/dev/null || echo scheme-tonal-spot)"
labels=()
for s in "${schemes[@]}"; do
  if [ "$s" = "$current" ]; then
    labels+=("$s ★")
  else
    labels+=("$s")
  fi
done

PS3="Select matugen scheme (number): "
select pick in "${labels[@]}"; do
  if [ -n "$pick" ]; then
    apply "${schemes[$((REPLY - 1))]}"
    break
  fi
done
