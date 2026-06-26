# nh — a faster, prettier front-end for `darwin-rebuild`/`nixos-rebuild`.
# Shows a dix-powered diff of exactly what changes before activation and
# renders nom build trees (both are bundled inside pkgs.nh and wrapped onto
# its own PATH — nothing extra to install). Installed via the upstream
# home-manager module, so no flake input is needed; `pkgs.nh` comes from
# nixpkgs (useGlobalPkgs).
#
# GC is handled deliberately elsewhere: a root `nh clean all` launchd daemon
# owns it (modules/system/darwin/nh-gc.nix). We do NOT set programs.nh.clean
# here — that runs `nh clean user`, which can't prune the *system*
# generations that actually accumulate (it refuses to run as root), so it
# would leave a second, weaker GC policy that does nothing useful here.
_: {
  flake.modules.homeManager.apps-nh =
    { config, ... }:
    {
      programs.nh = {
        enable = true;
        # Sets NH_FLAKE (nh ≥ 4.0), so `nh darwin switch` needs no path and
        # autodiscovers the host (config name == hostname == brett-m1-mbp).
        flake = "${config.home.homeDirectory}/nixos-config";
      };
    };
}
