# Universal home-manager baseline. Username and homeDirectory live in the host
# file (they vary per platform: /home/brett on Linux, /Users/brett on Darwin).
_: {
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    {
      home.stateVersion = "24.11";
      programs.home-manager.enable = true;
      home.sessionVariables.EDITOR = "nvim";

      # Copy apps to a fixed path instead of symlinking into the store (the
      # default from stateVersion 25.11). The Developer Tools exemption that
      # stops XProtect scanning every freshly built binary is keyed to kitty's
      # path, so a store symlink loses it on each kitty upgrade.
      targets.darwin = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        linkApps.enable = false;
        copyApps.enable = true;
      };
    };
}
