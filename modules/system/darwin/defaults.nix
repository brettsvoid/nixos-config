# Conservative macOS system defaults. Things that are widely loved without
# being personal preferences. Per-host or personal tweaks can layer on top.
_: {
  flake.modules.darwin.defaults = {
    system.defaults = {
      NSGlobalDomain = {
        # Show all file extensions in Finder
        AppleShowAllExtensions = true;
        # Faster key repeat
        InitialKeyRepeat = 15; # System Settings minimum is 15 (~225ms)
        KeyRepeat = 2; # System Settings minimum is 2 (~30ms)
      };
      finder = {
        AppleShowAllFiles = true; # show hidden files
        FXPreferredViewStyle = "clmv"; # column view
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
      };
      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.2;
        show-recents = false;
        tilesize = 48;
        mineffect = "scale";
      };
      screencapture = {
        location = "~/Pictures/Screenshots";
        type = "png";
      };
      trackpad = {
        Clicking = true; # tap to click
      };
    };
  };
}
