# Obsidian's attachment setting for the Syncthing-synced vault at
# ~/Documents/Obsidian Vault. The app itself is not installed from here.
#
# An activation script, not home.file: Obsidian rewrites .obsidian/app.json on
# every settings change, so a read-only store symlink would stop its settings
# persisting at all (and hand Syncthing a symlink to sync). Merging the one
# key with jq leaves the rest of the file to Obsidian.
#
# Quit Obsidian before switching: a running Obsidian writes its in-memory
# settings back on the next change, reverting this.
_: {
  flake.modules.homeManager.apps-obsidian =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      jq = "${pkgs.jq}/bin/jq";
      appJson = "${config.home.homeDirectory}/Documents/Obsidian Vault/.obsidian/app.json";

      # "In subfolder under current folder": pasted images go to _assets/
      # inside the note's folder (Recipes/ notes fill Recipes/_assets/), not
      # to the vault root, the stock default. The "./" prefix selects that
      # mode; a bare "_assets" means one shared folder at the vault root.
      attachmentPath = "./_assets";
    in
    {
      home.activation.obsidianAttachments = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        APP_JSON="${appJson}"

        # Absent on a machine that has not synced the vault yet — not an error.
        if [ -f "$APP_JSON" ]; then
          CURRENT=$(${jq} -r '.attachmentFolderPath // empty' "$APP_JSON")

          # Write only on a change, or Syncthing would sync (and version)
          # the file on every rebuild.
          if [ "$CURRENT" != "${attachmentPath}" ]; then
            ${jq} --arg p "${attachmentPath}" '.attachmentFolderPath = $p' "$APP_JSON" > "$APP_JSON.tmp" \
              && mv "$APP_JSON.tmp" "$APP_JSON"
          fi
        fi
      '';
    };
}
