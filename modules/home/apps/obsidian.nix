# Obsidian's attachment policy for the Syncthing-synced vault at
# ~/Documents/Obsidian Vault. The app itself is not installed from here.
#
# Deliberately an activation script rather than home.file/xdg.configFile.
# Obsidian rewrites .obsidian/app.json on EVERY settings change, so pointing a
# read-only store symlink at it would stop the settings pane persisting
# anything at all — the same trap terminals-herdr documents for its own config,
# but worse here, because Obsidian writes this file continuously rather than
# once at first run. Syncthing would also be handed a store symlink to sync.
# Merging the single key we care about with jq leaves the rest of the file, and
# Obsidian's ownership of it, alone.
#
# Operational note: quit Obsidian before `darwin-rebuild switch`. A running
# Obsidian holds its settings in memory and writes them back on the next
# change, silently reverting whatever activation wrote underneath it.
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

      # "In subfolder under current folder": images paste into an _assets/
      # beside the folder the note lives in, so Recipes/ notes fill
      # Recipes/_assets/ and nothing lands at the vault root (which is the
      # stock default, and how the root accumulated loose "Pasted image" files).
      #
      # The "./" prefix is load-bearing — it is what selects that mode. A bare
      # "_assets" is a different setting entirely: one shared folder at the
      # vault root. Confirmed against real vault configs, not inferred.
      attachmentPath = "./_assets";
    in
    {
      home.activation.obsidianAttachments = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        APP_JSON="${appJson}"

        # Absent on a machine that has not synced the vault yet — not an error.
        if [ -f "$APP_JSON" ]; then
          CURRENT=$(${jq} -r '.attachmentFolderPath // empty' "$APP_JSON")

          # Only write when the value actually differs. Syncthing watches this
          # vault, so an unconditional rewrite would emit a sync event and a
          # .stversions entry on every single rebuild.
          if [ "$CURRENT" != "${attachmentPath}" ]; then
            ${jq} --arg p "${attachmentPath}" '.attachmentFolderPath = $p' "$APP_JSON" > "$APP_JSON.tmp" \
              && mv "$APP_JSON.tmp" "$APP_JSON"
          fi
        fi
      '';
    };
}
