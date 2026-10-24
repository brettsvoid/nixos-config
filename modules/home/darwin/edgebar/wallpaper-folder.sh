# Print the wallpaper folder edgebar uses: `wallpaper.folder` from the last of
# its layers that sets it as a string, the Nix config.json and then the user's
# settings.json, with `~` expanded. A layer that isn't valid JSON is skipped,
# as edgebar skips it. DEFAULT_FOLDER (config.default.json's value) covers a
# missing config.json.
folder=$DEFAULT_FOLDER
for layer in "$HOME/.config/edgebar/config.json" "$HOME/.config/edgebar/settings.json"; do
  [ -f "$layer" ] || continue
  if value=$(jq -er '.wallpaper.folder? | strings' "$layer" 2>/dev/null); then
    folder=$value
  fi
done
case $folder in
"~") folder=$HOME ;;
"~/"*) folder="$HOME/${folder#\~/}" ;;
esac
printf '%s\n' "$folder"
