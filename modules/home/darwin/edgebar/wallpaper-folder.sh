folder=
for layer in "$BUNDLED_CONFIG" "$HOME/.config/edgebar/config.json" "$HOME/.config/edgebar/settings.json"; do
  [ -f "$layer" ] || continue
  if value=$(jq -er '.wallpaper.folder? | strings' "$layer" 2>/dev/null); then
    folder=$value
  fi
done
case $folder in
\~) folder=$HOME ;;
\~/*) folder="$HOME/${folder#\~/}" ;;
esac
printf '%s\n' "$folder"
