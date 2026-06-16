# skhd hotkey daemon config. Symlinks ~/.config/skhd → repo. skhd
# auto-reloads on file changes; saving an edit re-binds keys instantly.
#
# Brew-managed launchd plist owns the daemon (see notes in yabai.nix).
_: {
  flake.modules.homeManager.darwin-skhd =
    { config, ... }:
    {
      xdg.configFile."skhd".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/darwin/skhd";
    };
}
