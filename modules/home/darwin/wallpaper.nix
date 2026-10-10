# Sets the macOS desktop picture with `desktoppr`: nix-darwin has no
# wallpaper option, and the `System Events` AppleScript route has been broken
# since Sonoma.
#
# The image comes from ~/Pictures/Wallpapers, populated by the
# desktop-wallpapers home module, so import that alongside this one. The home
# path, unlike a /nix/store path, stays stable across GC.
#
# Per machine: set `local.wallpaper.default` in the host's home-manager block;
# it falls back to flake.lib.wallpaper.default.
#
# Activation seeds the wallpaper rather than pinning it: a stamp file records
# the last declared name applied, and desktoppr only runs when that changes.
# So `select-wallpaper`/`cycle-wallpaper` picks survive unchanged rebuilds.
{ config, ... }:
let
  wp = config.flake.lib.wallpaper;
in
{
  flake.modules.homeManager.darwin-wallpaper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.local.wallpaper;
      seed = pkgs.writeShellScript "seed-wallpaper" ''
        stamp="$HOME/.local/state/edgebar/wallpaper-default"
        want="${cfg.default}"
        [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && exit 0

        ${pkgs.desktoppr}/bin/desktoppr all "$HOME/${wp.dir}/$want" || exit 0
        mkdir -p "$(dirname "$stamp")"
        printf '%s' "$want" > "$stamp"
      '';
    in
    {
      options.local.wallpaper.default = lib.mkOption {
        type = lib.types.str;
        default = wp.default;
        example = "rem_demon.jpg";
        description = ''
          Filename of the desktop picture for this machine, relative to
          ~/${wp.dir}. Applied on the first activation that declares it, and
          again whenever this value changes — never on an unchanged rebuild.
        '';
      };

      config = {
        home.packages = [ pkgs.desktoppr ];

        # entryAfter writeBoundary so the wallpaper file (linked by
        # desktop-wallpapers) exists first.
        home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${seed}
        '';
      };
    };
}
