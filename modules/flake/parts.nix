# Enables the `flake.modules.<class>.<name>` registry. Leaf modules under
# modules/ write into it; hosts compose by referencing names.
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
}
