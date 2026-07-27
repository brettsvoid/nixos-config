# Declare `flake.darwinConfigurations` as a mergeable attrset so more than one
# host file can contribute a machine. Same reasoning as lib.nix: flake-parts
# otherwise treats it as one opaque flake output, and the second host file to
# define it fails with "defined multiple times … can't be merged".
#
# This only surfaces at the second host of a given class — one nixosSystem and
# one darwinSystem coexisted fine because they are different attributes.
#
# `raw` rather than `anything` (which lib.nix uses): a system configuration is
# an opaque value keyed by hostname, and deep-merging two of them is never what
# is wanted — hosts should stay independent. `lazyAttrsOf` so evaluating one
# host doesn't force the others.
#
# nixosConfigurations is deliberately NOT declared here: flake-parts declares it
# upstream (modules/nixosConfigurations.nix) as of 2026-07-01, and declaring it
# again is a hard error — "already declared in …". Drop this whole file if
# flake-parts ever ships the darwin equivalent too.
{ lib, ... }:
{
  options.flake.darwinConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "nix-darwin systems, one per host file under modules/hosts.";
  };
}
