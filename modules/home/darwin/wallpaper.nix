# Sets the macOS desktop picture. nix-darwin has no native wallpaper option,
# and the old `System Events` AppleScript route has been broken since Sonoma,
# so we drive `desktoppr` (NSWorkspace.setDesktopImageURL under the hood).
#
# The image comes from ~/Pictures/Wallpapers, which the `desktop-wallpapers`
# home module populates from modules/home/desktop/wallpapers — so this module
# requires that one to be imported alongside it (done in the host's imports).
# Pointing at the home copy rather than a /nix/store path keeps the wallpaper
# stable across GC and visible in Finder.
#
# Per machine: set `local.wallpaper.default` in the host file's home-manager
# block. It falls back to flake.lib.wallpaper.default when a host says nothing.
#
# Activation SEEDS the wallpaper, it does not pin it. A stamp file records the
# declared name that was last applied, and we only call desktoppr when the
# declared name differs. So `select-wallpaper`/`cycle-wallpaper` picks survive
# every later rebuild, while editing the host's default still takes effect on
# the next switch.
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
