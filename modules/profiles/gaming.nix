# Gaming profile. Linux-heavy (Steam, gamemode, etc.); the homeManager half
# applies cross-platform for the chat-and-launcher pieces.
_: {
  flake.modules.nixos.profile-gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
      };
      programs.gamemode.enable = true;
      environment.systemPackages = with pkgs; [
        lutris
        mangohud
        heroic
      ];
    };

  flake.modules.homeManager.profile-gaming =
    { pkgs, lib, ... }:
    lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        discord
        prismlauncher
      ];
    };
}
