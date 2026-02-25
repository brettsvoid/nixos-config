{ config, pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "layout.frame_rate" = -1; # auto-detect monitor refresh rate
        "gfx.webrender.all" = true;
        "browser.startup.page" = 3; # restore previous session
      };
    };
  };
}
