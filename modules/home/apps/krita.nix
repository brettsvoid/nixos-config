# Krita from nixpkgs, which builds it for Linux only.
_: {
  flake.modules.homeManager.apps-krita =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.krita ];
    };
}
