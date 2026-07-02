# skhd hotkey daemon config. Symlinks ~/.config/skhd → repo. skhd
# auto-reloads on file changes; saving an edit re-binds keys instantly.
#
# Brew-managed launchd plist owns the daemon (see notes in yabai.nix).
{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.darwin-skhd =
    { config, ... }:
    {
      xdg.configFile."skhd".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/darwin/skhd";
    };
}
