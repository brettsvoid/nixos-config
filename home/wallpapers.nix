{ config, pkgs, ... }:

{
  home.file."Pictures/Wallpapers".source = ./wallpapers;

  home.activation.updateWallpaperPath = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    WALLPAPERS_JSON="${config.home.homeDirectory}/.cache/ambxst/wallpapers.json"
    NEW_PATH="$(readlink -f "${config.home.homeDirectory}/Pictures/Wallpapers")"

    if [ -f "$WALLPAPERS_JSON" ]; then
      ${pkgs.jq}/bin/jq --arg p "$NEW_PATH" '.wallPath = $p' "$WALLPAPERS_JSON" > "$WALLPAPERS_JSON.tmp" \
        && mv "$WALLPAPERS_JSON.tmp" "$WALLPAPERS_JSON"
    else
      mkdir -p "$(dirname "$WALLPAPERS_JSON")"
      echo '{}' | ${pkgs.jq}/bin/jq --arg p "$NEW_PATH" '.wallPath = $p' > "$WALLPAPERS_JSON"
    fi
  '';
}
