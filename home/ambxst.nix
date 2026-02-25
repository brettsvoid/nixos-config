{ config, pkgs, ... }:

let
  jq = "${pkgs.jq}/bin/jq";
  configDir = "${config.home.homeDirectory}/.config/ambxst/config";
  cacheDir = "${config.home.homeDirectory}/.cache/ambxst";
in
{
  home.activation.ambxstConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # ── Bar settings ──────────────────────────────────────────────
    BAR_JSON="${configDir}/bar.json"
    if [ -f "$BAR_JSON" ]; then
      ${jq} '.frameEnabled = true | .frameThickness = 4' "$BAR_JSON" > "$BAR_JSON.tmp" \
        && mv "$BAR_JSON.tmp" "$BAR_JSON"
    fi

    # ── Wallpaper path ────────────────────────────────────────────
    WALLPAPERS_JSON="${cacheDir}/wallpapers.json"
    NEW_PATH="$(readlink -f "${config.home.homeDirectory}/Pictures/Wallpapers")"

    DEFAULT_WALL="$NEW_PATH/chisato_petals_of_silence_4k.jpg"

    if [ -f "$WALLPAPERS_JSON" ]; then
      ${jq} --arg p "$NEW_PATH" --arg w "$DEFAULT_WALL" '
        .wallPath = $p |
        .currentWall = (.currentWall | sub("^.*/(?<f>[^/]+)$"; $p + "/" + .f) // $w) |
        .activeColorPreset //= "" |
        .matugenScheme //= "scheme-neutral" |
        .tintEnabled //= false
      ' "$WALLPAPERS_JSON" > "$WALLPAPERS_JSON.tmp" \
        && mv "$WALLPAPERS_JSON.tmp" "$WALLPAPERS_JSON"
    else
      mkdir -p "${cacheDir}"
      echo '{}' | ${jq} --arg p "$NEW_PATH" --arg w "$DEFAULT_WALL" '
        .wallPath = $p |
        .currentWall = $w |
        .activeColorPreset = "" |
        .matugenScheme = "scheme-neutral" |
        .tintEnabled = false
      ' > "$WALLPAPERS_JSON"
    fi
  '';
}
