_: {
  flake.modules.homeManager.desktop-wallpapers =
    { config, ... }:
    {
      # A real directory with a link per image, not one link to the whole
      # directory: Caelestia's file watcher follows a directory link once at
      # start-up, so after a rebuild re-points it the running shell never sees
      # new images. Other modules add images here too (desktop-caelestia).
      home.file."Pictures/Wallpapers" = {
        source = ./wallpapers;
        recursive = true;
      };

      # One-off migration from the old whole-directory link: home-manager would
      # keep it (the path still exists, as a directory) and then link images
      # into the read-only store path it points at. A no-op once it is a
      # directory.
      home.activation.wallpapersDirLink = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/Pictures/Wallpapers" ]; then
          run rm $VERBOSE_ARG "$HOME/Pictures/Wallpapers"
        fi
      '';
    };
}
