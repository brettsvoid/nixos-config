# Spotify, with a launcher that carries its volume across crashes.
#
# Spotify saves its volume (`app.player.volume`, slider × 65535, in
# ~/.config/spotify/Users/<id>-user/prefs) only on a clean quit, which it
# rarely gets: it ignores SIGTERM and crashes at shutdown. At launch it pushes
# that value onto its PipeWire stream, overriding WirePlumber's restored
# volume, and with none saved it starts at 100%.
#
# WirePlumber records the stream volume on every change (cubed, hence the
# cube root) in ~/.local/state/wireplumber/stream-properties, so the launcher
# copies it into the prefs before starting Spotify. WirePlumber only sees
# changes while Spotify is playing; one made while paused reaches only the
# prefs, so a prefs file newer than WirePlumber's record is left alone.
_: {
  flake.modules.homeManager.apps-spotify =
    { pkgs, ... }:
    let
      launcher = pkgs.writeShellApplication {
        name = "spotify";
        runtimeInputs = with pkgs; [
          gnused
          jq
        ];
        text = ''
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/wireplumber/stream-properties"
          users="''${XDG_CONFIG_HOME:-$HOME/.config}/spotify/Users"

          level=""
          if [ -r "$state" ]; then
            # The value after "=" is plain JSON; Spotify sets every channel alike.
            level="$(
              sed -n 's|^Output/Audio:application\.name:spotify=||p' "$state" |
                jq -r '.channelVolumes[0] // empty | [cbrt * 65535 | round, 65535] | min' \
                  2>/dev/null || true
            )"
          fi

          if [ -n "$level" ]; then
            for prefs in "$users"/*-user/prefs; do
              [ -f "$prefs" ] || continue
              [ "$prefs" -nt "$state" ] && continue
              sed -i -e '/^app\.player\.volume=/d' -e "\$a app.player.volume=$level" "$prefs"
            done
          fi

          exec ${pkgs.spotify}/bin/spotify "$@"
        '';
      };
    in
    {
      # Same package with bin/spotify swapped for the launcher. The desktop
      # entry runs a bare `spotify`, so launchers pick this up through PATH.
      home.packages = [
        (pkgs.symlinkJoin {
          name = "spotify-${pkgs.spotify.version}";
          paths = [ pkgs.spotify ];
          postBuild = ''
            rm "$out/bin/spotify"
            ln -s ${launcher}/bin/spotify "$out/bin/spotify"
          '';
        })
      ];
    };
}
