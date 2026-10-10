# EXTERNAL_BAR_HEIGHT comes from flake.lib.barGeometry, which sketchybar.nix
# renders into the vars file below. Set it in bar-geometry.nix (it also drives
# the AeroSpace gaps) and rebuild; the rest of this dir is read live.
source "$HOME/.config/sketchybar-vars.sh"
