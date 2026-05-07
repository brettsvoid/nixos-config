_: {
  flake.modules.homeManager.apps-spotify =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.spotify ];
    };
}
