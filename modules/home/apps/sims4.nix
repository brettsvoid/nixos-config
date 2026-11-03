# The Sims 4 (Steam, Proton). Mods are installed by hand, a folder per mod,
# into the Proton prefix's Mods folder. This module adds a short link to it and
# `sims4-prep`, to run after a game patch or a mod change: it backs up the saves
# and clears the thumbnail and sim texture caches, which go stale when mods
# change (a stale sim texture cache showed sims' skin as black).
_: {
  flake.modules.homeManager.apps-sims4 =
    { config, pkgs, ... }:
    let
      userDir = "${config.xdg.dataHome}/Steam/steamapps/compatdata/1222670/pfx/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 4";
      backups = "${config.home.homeDirectory}/Games/Sims4Backups";

      sims4-prep = pkgs.writeShellApplication {
        name = "sims4-prep";
        runtimeInputs = with pkgs; [
          gnutar
          gzip
          procps
        ];
        text = ''
          dir=${pkgs.lib.escapeShellArg userDir}
          if pgrep -f TS4_x64 >/dev/null; then
            echo "The Sims 4 is running; close it first." >&2
            exit 1
          fi
          mkdir -p ${backups}
          out=${backups}/saves-$(date +%Y%m%d-%H%M%S).tar.gz
          tar -czf "$out" -C "$dir" saves
          echo "Saves backed up to $out"
          rm -f "$dir/localthumbcache.package" "$dir/localsimtexturecache.package"
          echo "Thumbnail and sim texture caches cleared."
        '';
      };
    in
    {
      home.packages = [ sims4-prep ];
      home.file."Games/Sims4Mods".source = config.lib.file.mkOutOfStoreSymlink "${userDir}/Mods";
    };
}
