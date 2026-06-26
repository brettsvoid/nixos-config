# Single source of truth for the top-of-screen bar geometry shared by the
# sketchybar status bar (modules/home/darwin/sketchybar) and the AeroSpace
# window gaps (modules/home/darwin/aerospace).
#
# AeroSpace's TOML can't reference variables or env vars, and there's no
# runtime command to set gaps — they're read from the file on reload-config.
# So instead of hand-syncing two numbers, we keep the height here and render
# both consumers from it at build time:
#   - sketchybar.nix writes ~/.config/sketchybar-vars.sh (EXTERNAL_BAR_HEIGHT)
#   - aerospace.nix substitutes outerTop into aerospace.toml
# Set the height here; rebuild to apply.
_: {
  flake.lib.barGeometry = rec {
    # Full height the sketchybar bar reserves at the top of the screen
    # (sketchybar's EXTERNAL_BAR_HEIGHT).
    height = 52;

    # The bar centres a (height - 2*padding) pill inside `height`, leaving
    # `padding` px of empty space *below* the visible pill — that strip is the
    # gap under the bar. Mirrors sketchybar's PADDING (sketchybarrc) and the
    # AeroSpace window gap (aerospace.toml inner/outer = 8); keep them equal.
    padding = 8;

    # Where AeroSpace starts tiling windows. The pill bottom sits at
    # (height - padding); we want one `padding`-sized gap below it, so
    #   outerTop = (height - padding) + padding = height.
    # Using `height` (not the old height + padding = 60) is the fix for the
    # double gap between the bar and the windows.
    outerTop = height + 2;
  };
}
