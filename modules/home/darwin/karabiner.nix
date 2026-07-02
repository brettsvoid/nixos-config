# Karabiner-Elements config. Symlinks ~/.config/karabiner/karabiner.json →
# repo (out-of-store), so edits take effect live: Karabiner watches the file
# and reloads on save — no rebuild required.
#
# Only the JSON is symlinked, not the whole karabiner dir, so Karabiner's
# own `assets/` and `automatic_backups/` stay as real files in ~/.config.
#
# Karabiner-Elements itself is installed as a Homebrew cask (see
# modules/system/darwin/homebrew.nix). Current key map: caps_lock →
# backspace, right_command → Hyper (⌃⌥⇧⌘) with vim-style sublayers.
{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.darwin-karabiner =
    { config, ... }:
    {
      xdg.configFile."karabiner/karabiner.json".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/darwin/karabiner/karabiner.json";
    };
}
