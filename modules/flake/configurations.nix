# Declare `flake.darwinConfigurations` as a mergeable attrset so each host file
# can add a machine. As with lib.nix, flake-parts otherwise treats it as one
# opaque output and the second host file fails with "defined multiple times …
# can't be merged". `raw`, not `anything`: hosts must never be deep-merged.
# `lazyAttrsOf` so evaluating one host doesn't force the others.
#
# Don't declare nixosConfigurations here: flake-parts already does
# (modules/nixosConfigurations.nix), and a second declaration is an error.
# Drop this file if flake-parts adds the darwin equivalent.
{ lib, ... }:
{
  options.flake.darwinConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "nix-darwin systems, one per host file under modules/hosts.";
  };
}
