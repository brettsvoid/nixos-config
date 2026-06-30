# herdr — terminal agent-multiplexer: run coding agents in one terminal,
# sessions persist over ssh (https://herdr.dev). Trialled alongside tmux
# (terminals-tmux); both stay installed so they can be compared side by side.
# Pulled from the `herdr` flake input rather than nixpkgs (not packaged there).
{ inputs, ... }:
{
  flake.modules.homeManager.terminals-herdr =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
