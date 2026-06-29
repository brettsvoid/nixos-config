# Renders edgebar's runtime config (~/.config/edgebar/config.json) so the one
# value that must stay in sync with AeroSpace's window gaps — the bar height —
# is single-sourced in Nix (flake.lib.barGeometry, see bar-geometry.nix) and
# shared with aerospace.nix's outer.top.
#
# Colors/role-maps + geometry stay editable in the committed source of truth,
# apps/edgebar/src-tauri/config.default.json (also the binary's bundled
# fallback); we import that and override only geometry.barHeight, so editing it
# there + rebuild is all that's needed. edgebar reads this file at startup,
# falling back to the bundled default when it's absent.
#
# The wallpaper-derived PALETTE is separate: `generate-edgebar-theme` runs
# matugen (edgebar/matugen) over the current wallpaper to write
# ~/.config/edgebar/palette.json (light + dark), then pings edgebar's theme.sock
# so the running bar re-themes live. edgebar falls back to the bundled
# palette.default.json (Catppuccin Latte/Mocha) when that file is absent.
{ config, lib, ... }:
let
  geom = config.flake.lib.barGeometry;
  defaults = lib.importJSON ../../../apps/edgebar/src-tauri/config.default.json;
  rendered = defaults // {
    geometry = defaults.geometry // {
      barHeight = geom.barHeight;
      # fillet radius is locked to half the pill height
      concave = defaults.geometry.pillHeight / 2;
    };
  };
  matugenDir = ./edgebar/matugen;
in
{
  flake.modules.homeManager.darwin-edgebar =
    { pkgs, lib, ... }:
    let
      # Default wallpaper kept in sync with darwin/wallpaper.nix.
      defaultWallpaper = "$HOME/Pictures/Wallpapers/chisato_petals_of_silence_4k.jpg";
      generate-edgebar-theme = pkgs.writeShellScriptBin "generate-edgebar-theme" ''
        CONFIG_DIR="${matugenDir}"
        SCHEME="scheme-tonal-spot"
        WALLPAPER=""

        # generate-edgebar-theme [wallpaper] [--scheme scheme-*]
        while [ $# -gt 0 ]; do
          case "$1" in
            --scheme) SCHEME="$2"; shift 2 ;;
            *) WALLPAPER="$1"; shift ;;
          esac
        done

        # Resolve the wallpaper: explicit arg > ambxst's current selection > the
        # rebuild default (the image darwin/wallpaper.nix sets).
        if [ -z "$WALLPAPER" ] && [ -f "$HOME/.cache/ambxst/wallpapers.json" ]; then
          WALLPAPER=$(${pkgs.jq}/bin/jq -r '.currentWall // empty' "$HOME/.cache/ambxst/wallpapers.json")
        fi
        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          WALLPAPER="${defaultWallpaper}"
        fi
        if [ ! -f "$WALLPAPER" ]; then
          echo "generate-edgebar-theme: no wallpaper found ($WALLPAPER)" >&2
          exit 1
        fi

        echo "edgebar theme ← $WALLPAPER (scheme: $SCHEME)"
        if ! ${pkgs.matugen}/bin/matugen image "$WALLPAPER" \
          --source-color-index 0 \
          -c "$CONFIG_DIR/config.toml" \
          -t "$SCHEME"; then
          echo "matugen failed — palette not regenerated" >&2
          exit 1
        fi
      '';
    in
    {
      xdg.configFile."edgebar/config.json".text = builtins.toJSON rendered;

      home.packages = [ generate-edgebar-theme ];

      # Seed palette.json from the wallpaper on first build (later wallpaper
      # changes are driven by running generate-edgebar-theme). Absent the file,
      # edgebar uses the bundled Catppuccin fallback, so a matugen failure here
      # is non-fatal.
      home.activation.edgebarTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "$HOME/.config/edgebar/palette.json" ]; then
          run ${generate-edgebar-theme}/bin/generate-edgebar-theme || true
        fi
      '';
    };
}
