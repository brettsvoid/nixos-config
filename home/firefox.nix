{ config, pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "layout.frame_rate" = -1; # auto-detect monitor refresh rate
        "gfx.webrender.all" = true;
        "widget.wayland.vsync.enabled" = true; # sync to compositor frame callbacks for full refresh rate
        "browser.startup.page" = 3; # restore previous session
      };
    };
  };
}
