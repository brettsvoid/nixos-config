# hey: CLI and TUI for HEY email and calendar
# (https://github.com/basecamp/hey-cli). Taken from the `hey-cli` flake input,
# which installs shell completions. Run `hey` once to sign in.
{ inputs, ... }:
{
  flake.modules.homeManager.apps-hey =
    { pkgs, ... }:
    {
      home.packages = [ inputs.hey-cli.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };
}
