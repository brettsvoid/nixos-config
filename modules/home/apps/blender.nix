# Blender from nixpkgs rather than the Homebrew cask. The darwin build
# installs a real Blender.app bundle (plus a `blender` CLI wrapper), which
# home-manager's targets.darwin.linkApps symlinks into
# ~/Applications/Home Manager Apps — the same route terminals-kitty takes.
#
# nixpkgs is the preferred source for anything it packages; a cask is the
# fallback for what it does not. Beyond the usual pinning argument, casks
# are exposed to artifact skew: the blender cask declares a
# `command_wrapper`, the artifact type whose arrival in the kitty cask
# aborted `brew bundle` mid-activation on the mini (see that host file).
#
# Preferences live in ~/Library/Application Support/Blender/<major.minor>,
# outside the store, so upgrades leave them alone and each series keeps its
# own directory.
_: {
  flake.modules.homeManager.apps-blender =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.blender ];
    };
}
