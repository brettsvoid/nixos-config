# Declare `flake.lib` as a mergeable attrset so more than one leaf module can
# contribute keys (bar-geometry.nix → barGeometry, design.nix → theme/wallpaper,
# …). Without this, flake-parts treats flake.lib as one opaque output and a
# second definition conflicts ("defined multiple times … can't be merged").
{ lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.anything;
    default = { };
    description = "Shared constants and helpers, exposed as the flake's `lib` output.";
  };
}
