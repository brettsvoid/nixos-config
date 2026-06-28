# Single source of truth for the top-of-screen bar geometry shared by the
# edgebar overlay (apps/edgebar) and the AeroSpace window gaps
# (modules/home/darwin/aerospace).
#
# AeroSpace's TOML can't reference variables or env vars, and there's no
# runtime command to set gaps — they're read from the file on reload-config.
# edgebar's bar height was likewise a compiled-in constant. So instead of
# hand-syncing the number across both, we keep it here and render both
# consumers from it at build time:
#   - edgebar.nix writes ~/.config/edgebar/config.json (geometry.barHeight)
#   - aerospace.nix substitutes outerTop into aerospace.toml
# Set the height here; rebuild to apply.
#
# (sketchybar.nix still reads barHeight for EXTERNAL_BAR_HEIGHT, but the
# sketchybar daemon is disabled — edgebar replaced it.)
_: {
  flake.lib.barGeometry = rec {
    # Height of the edgebar bar band at the top of the screen — its interactive
    # strip, and the vertical space AeroSpace must clear for the bar. Rendered
    # into edgebar's config.json (geometry.barHeight) and into outerTop below.
    barHeight = 32;

    # Gap between tiled windows (AeroSpace inner.horizontal/vertical). Also used
    # as the gap below the bar, so the space under the bar reads the same as the
    # space between windows.
    innerGap = 8;

    # Screen-edge inset around the tiled area (AeroSpace outer.left/right/bottom).
    outerGap = 10;

    # Where AeroSpace starts tiling windows
    outerTop = barHeight + outerGap - 2;
  };
}
