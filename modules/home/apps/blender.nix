# Blender from nixpkgs rather than the Homebrew cask. On darwin the package
# ships Blender.app (plus a `blender` wrapper), which home-manager's
# targets.darwin.linkApps symlinks into ~/Applications/Home Manager Apps.
# The cask would also bring a `command_wrapper` artifact, the type that broke
# `brew bundle` on the mini (see modules/hosts/brett-mac-mini.nix).
#
# Preferences live outside the store, in
# ~/Library/Application Support/Blender/<major.minor> (~/.config/blender on
# Linux).
#
# On Linux this is the build without CUDA (nixpkgs' cudaSupport is off), so
# Cycles renders on the CPU only. cache.nixos.org has no CUDA build, so
# turning it on means compiling Blender locally.
_: {
  flake.modules.homeManager.apps-blender =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.blender ];
    };
}
