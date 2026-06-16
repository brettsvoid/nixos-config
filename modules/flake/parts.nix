# Enables `flake.modules.<class>.<name>` registry. Every leaf module under
# modules/ writes into this registry; hosts compose by referencing names.
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
}
