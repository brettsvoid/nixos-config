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
{ config, ... }:
let
  geom = config.flake.lib.barGeometry;
in
{
  flake.modules.homeManager.darwin-aerospace =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # A list, not an attrset: order decides which rule wins, and attrset keys
      # would sort 'com.google.Chrome' above 'com.google.Chrome.app.<id>' — so a
      # Chrome PWA would land wherever plain Chrome goes.
      windowRules = lib.concatMapStrings (rule: ''

        [[on-window-detected]]
        if.app-id = '${rule.appId}'
        run = 'move-node-to-workspace ${rule.workspace}'
      '') config.local.aerospace.windowAssignments;

      aerospaceToml = pkgs.replaceVars ./aerospace/aerospace.toml.in {
        outerTop = toString geom.outerTop;
        innerGap = toString geom.innerGap;
        outerGap = toString geom.outerGap;
        inherit windowRules;
      };
    in
    {
      options.local.aerospace.windowAssignments = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              appId = lib.mkOption {
                type = lib.types.str;
                example = "net.kovidgoyal.kitty";
                description = "CFBundleIdentifier, as reported by `aerospace list-windows --all --json --format '%{app-bundle-id}%{app-name}%{workspace}'`.";
              };
              workspace = lib.mkOption {
                type = lib.types.str;
                example = "1";
                description = "Workspace this app's windows move to when detected.";
              };
            };
          }
        );
        default = [ ];
        description = ''
          Apps this machine pins to a workspace, rendered into aerospace.toml as
          `[[on-window-detected]]` blocks. Order matters: only the first matching
          rule runs, so put narrower bundle IDs before the ones they extend.

          Rules fire on window detection, so they do not move windows that are
          already open. Apply them to the current session with
          `aerospace run-callback --for-every-window on-window-detected`.
        '';
      };

      config.xdg.configFile."aerospace".source = pkgs.linkFarm "aerospace-config" [
        {
          name = "aerospace.toml";
          path = aerospaceToml;
        }
      ];

      # Apply config changes (e.g. the bar gap) on every `darwin-rebuild
      # switch`. Runs after writeBoundary so the rendered toml is already
      # linked. `|| true` keeps the switch from failing when the daemon isn't
      # running yet (first install).
      config.home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.aerospace}/bin/aerospace reload-config || true
      '';
    };
}
