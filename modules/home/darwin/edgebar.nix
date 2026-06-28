# Renders edgebar's runtime config (~/.config/edgebar/config.json) so the one
# value that must stay in sync with AeroSpace's window gaps — the bar height —
# is single-sourced in Nix (flake.lib.barGeometry, see bar-geometry.nix) and
# shared with aerospace.nix's outer.top.
#
# Colors/palette stay editable in the committed source of truth,
# apps/edgebar/src-tauri/config.default.json (also the binary's bundled
# fallback); we import that and override only geometry.barHeight, so editing
# colors there + rebuild is all that's needed. edgebar reads this file at
# startup, falling back to the bundled default when it's absent.
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
in
{
  flake.modules.homeManager.darwin-edgebar =
    { ... }:
    {
      xdg.configFile."edgebar/config.json".text = builtins.toJSON rendered;
    };
}
