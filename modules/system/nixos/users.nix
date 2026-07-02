# Brett's NixOS user account.
_: {
  flake.modules.nixos.users =
    { pkgs, flake, ... }:
    {
      users.users.${flake.lib.username} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "render"
        ];
        shell = pkgs.zsh;
      };
    };
}
