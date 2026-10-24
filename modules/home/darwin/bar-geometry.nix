# Single source of truth for the top-of-screen bar geometry, shared by the
# edgebar overlay (apps/edgebar) and the AeroSpace window gaps. AeroSpace's
# TOML can't reference variables and has no runtime command to set gaps, so
# both consumers are rendered from here at build time; rebuild to apply:
#   - edgebar.nix writes ~/.config/edgebar/config.json (geometry.barHeight)
#   - aerospace.nix substitutes the gaps below into aerospace.toml
# sketchybar.nix also reads barHeight, but the sketchybar daemon is disabled.
_: {
  flake.lib.barGeometry = rec {
    # Height of edgebar's bar band: its interactive strip, and the space
    # AeroSpace must clear. Also feeds outerTop below.
    barHeight = 32;

    # Thickness of edgebar's frame on the sides and bottom (the band is the top).
    # Here rather than only in edgebar's config because the gaps below clear it.
    frameThickness = 8;

    # Gap between tiled windows (AeroSpace inner.horizontal/vertical).
    innerGap = 8;

    # Gap between the frame and the tiled windows, as the custom shell's gaps_out.
    windowGap = 8;

    # Screen-edge inset around the tiled area (AeroSpace outer.left/right/bottom).
    outerGap = frameThickness + windowGap;

    # Top of the tiled area: the bar band plus the window gap below it.
    outerTop = barHeight + windowGap;
  };
}
