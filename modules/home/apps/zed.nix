# Zed's settings and extensions. The app itself is not installed from here.
# settings.json stays writable: each switch merges these keys over it, so a
# change made in Zed lasts until it clashes with one set here.
_: {
  flake.modules.homeManager.apps-zed = {
    programs.zed-editor = {
      enable = true;
      package = null;
      extensions = [
        "html"
        "lua"
      ];
      userSettings = {
        theme = "Andromeda";
        vim_mode = true;
        ui_font_size = 16;
        buffer_font_size = 16;
      };
    };
  };
}
