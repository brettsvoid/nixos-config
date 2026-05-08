# Yabai window manager config. Symlinks ~/.config/yabai → repo so edits
# take effect on `yabai --restart-service`.
#
# Brew-managed launchd plist (~/Library/LaunchAgents/com.koekeishiya.yabai.plist)
# still owns the daemon. nix-darwin's services.yabai is intentionally NOT
# enabled here — switching the launchd ownership during Phase C is high-risk
# and the brew binary works fine.
_: {
  flake.modules.homeManager.darwin-yabai =
    { config, ... }:
    {
      xdg.configFile."yabai".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/home/darwin/yabai";
    };
}
