# Declare `flake.{nixos,darwin}Configurations` as mergeable attrsets so more
# than one host file can contribute a machine. Same reasoning as lib.nix:
# flake-parts otherwise treats each as one opaque flake output, and the second
# host file to define it fails with "defined multiple times … can't be merged".
#
# This only surfaces at the second host of a given class — one nixosSystem and
# one darwinSystem coexisted fine because they are different attributes.
#
# `raw` rather than `anything` (which lib.nix uses): a system configuration is
# an opaque value keyed by hostname, and deep-merging two of them is never what
# is wanted — hosts should stay independent. `lazyAttrsOf` so evaluating one
# host doesn't force the others.
{ lib, ... }:
{
  options.flake = {
    nixosConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "NixOS systems, one per host file under modules/hosts.";
    };
    darwinConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "nix-darwin systems, one per host file under modules/hosts.";
    };
  };
}
