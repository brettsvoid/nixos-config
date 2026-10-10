# AeroSpace config. aerospace.toml is rendered from aerospace/aerospace.toml.in,
# substituting the gaps from flake.lib.barGeometry (bar-geometry.nix) and the
# per-host window rules, so edits need `darwin-rebuild switch` (which also
# reloads AeroSpace; see reloadAerospace below).
#
# ~/.config/aerospace is managed as a whole directory (one linkFarm symlink),
# not as a file nested under it. A nested file under a path home-manager
# previously linked as a directory gets written through the stale link
# instead; that once leaked the rendered toml back into this repo.
#
# Pair with `flake.modules.darwin.window-manager-aerospace`, which installs
# the package and launchd agent.
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
          `[[on-window-detected]]` blocks. `appId` must match the bundle ID
          exactly; if two rules match, only the first runs.

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

      # Reload on every switch, after writeBoundary so the new toml is
      # linked. `|| true` keeps the switch from failing when the daemon isn't
      # running yet (first install).
      config.home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.aerospace}/bin/aerospace reload-config || true
      '';
    };
}
