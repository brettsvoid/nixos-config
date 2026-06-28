# AeroSpace config. aerospace.toml is generated from aerospace/aerospace.toml.in
# by substituting @outerTop@ from flake.lib.barGeometry (the single source of
# the bar height, shared with sketchybar — see modules/home/darwin/bar-geometry.nix).
#
# AeroSpace's TOML can't reference variables, so this is the only way to keep
# the window gap in sync with the bar height. Trade-off vs the old
# mkOutOfStoreSymlink: edits now need `darwin-rebuild switch` before
# `aerospace reload-config` (the file is no longer live-edited in place).
#
# We manage ~/.config/aerospace as a whole directory (one symlink to a store
# dir built by linkFarm), NOT a file nested under it. Managing a file *under* a
# path that home-manager previously symlinked as a directory makes activation
# write *through* the stale directory symlink instead of replacing it — which
# leaked the rendered aerospace.toml back into this repo on every rebuild.
# A directory-level link reuses the original `aerospace` key, so home-manager
# cleanly swaps the symlink.
#
# Pair this module with `flake.modules.darwin.window-manager-aerospace`,
# which installs the package + launchd agent.
#
# Swapping with the yabai stack: in modules/hosts/brett-m1-mbp.nix, replace
# the `darwin-yabai` / `darwin-skhd` imports with `darwin-aerospace` and
# the system module `window-manager` with `window-manager-aerospace`.
{ config, ... }:
let
  geom = config.flake.lib.barGeometry;
in
{
  flake.modules.homeManager.darwin-aerospace =
    { pkgs, lib, ... }:
    let
      aerospaceToml = pkgs.replaceVars ./aerospace/aerospace.toml.in {
        outerTop = toString geom.outerTop;
        innerGap = toString geom.innerGap;
        outerGap = toString geom.outerGap;
      };
    in
    {
      xdg.configFile."aerospace".source = pkgs.linkFarm "aerospace-config" [
        {
          name = "aerospace.toml";
          path = aerospaceToml;
        }
      ];

      # Apply config changes (e.g. the bar gap) on every `darwin-rebuild
      # switch`. Runs after writeBoundary so the rendered toml is already
      # linked. `|| true` keeps the switch from failing when the daemon isn't
      # running yet (first install).
      home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.aerospace}/bin/aerospace reload-config || true
      '';
    };
}
