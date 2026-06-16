# Brett's NixOS user account.
_: {
  flake.modules.nixos.users =
    { pkgs, ... }:
    {
      users.users.brett = {
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
