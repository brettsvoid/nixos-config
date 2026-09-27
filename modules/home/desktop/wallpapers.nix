_: {
  flake.modules.homeManager.desktop-wallpapers =
    { config, ... }:
    {
      # A real directory with a link per image, not one link to the whole
      # directory. Caelestia's file watcher follows the directory link once at
      # start-up, so when a rebuild points that link at a new store path the
      # running shell never sees images added since. Per-image links land in a
      # directory it is already watching. Other modules can add images here
      # (desktop-caelestia adds Crimson Ronin's).
      home.file."Pictures/Wallpapers" = {
        source = ./wallpapers;
        recursive = true;
      };

      # One-off migration from the old whole-directory link. home-manager's
      # cleanup keeps that link (the path still exists in the new generation,
      # as a directory), so linking would then write into the read-only store
      # path it points at. Remove it first; a no-op once it is a directory.
      home.activation.wallpapersDirLink = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/Pictures/Wallpapers" ]; then
          run rm $VERBOSE_ARG "$HOME/Pictures/Wallpapers"
        fi
      '';
    };
}
