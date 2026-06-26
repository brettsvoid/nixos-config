# Bar geometry is single-sourced in Nix (flake.lib.barGeometry, see
# modules/home/darwin/bar-geometry.nix) and rendered to this file by
# sketchybar.nix. AeroSpace reads the same constant for its window gaps, so
# set the height there, not here. This dir stays a live-edit symlink; only the
# generated vars file below requires a rebuild to change.
source "$HOME/.config/sketchybar-vars.sh"
