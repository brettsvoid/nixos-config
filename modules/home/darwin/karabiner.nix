# Karabiner-Elements config. Symlinks ~/.config/karabiner/karabiner.json →
# repo (out-of-store), so edits take effect live: Karabiner watches the file
# and reloads on save — no rebuild required.
#
# Only the JSON is symlinked, not the whole karabiner dir, so Karabiner's
# own `assets/` and `automatic_backups/` stay as real files in ~/.config.
#
# Karabiner-Elements itself is installed as a Homebrew cask (see
# modules/system/darwin/homebrew.nix). Current key map: caps_lock →
# backspace ON THE BUILT-IN KEYBOARD ONLY, right_command → Hyper (⌃⌥⇧⌘)
# with vim-style sublayers.
#
# One karabiner.json is shared by both Macs, so there is no host condition
# to work with — only device conditions. `is_built_in_keyboard` is the
# machine discriminator: the MacBook has one, the Mac mini does not. That
# scopes caps_lock → backspace to the MacBook, and leaves caps_lock alone on
# the mini's Moonlander, which handles its own remapping in firmware.
#
# There used to be a rule ahead of that one mapping caps_lock → F18 on the
# built-in keyboard, to trigger skhd's `hyper_mode`. It was removed: skhd is
# only imported by the yabai branch of the wmStack switch in modules/hosts,
# and both hosts select aerospace, which binds nothing to F18. Because
# Karabiner takes the FIRST matching manipulator, that rule also shadowed the
# backspace mapping on the MacBook's built-in keyboard — external keyboards
# got backspace, the built-in one got a dead key. Re-adding it only makes
# sense together with skhd.
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
