# Spotify, with a launcher that carries its volume across crashes.
#
# ─── The problem ───────────────────────────────────────────────────────
# Spotify keeps its own volume as `app.player.volume` (slider × 65535) in
# ~/.config/spotify/Users/<id>-user/prefs, and writes it ONLY on a clean quit
# (window close or MPRIS Quit). It ignores SIGTERM, and powering off from the
# shell takes XWayland down under it, so in practice it crashed at shutdown
# (SIGTRAP coredump) and never saved. At launch it pushes that saved value onto
# its PipeWire stream, overriding WirePlumber's restored per-app volume, and
# with no saved value it starts at 100%. Net effect: full volume every launch.
#
# ─── The fix ───────────────────────────────────────────────────────────
# WirePlumber already records Spotify's stream volume on every change, in
# ~/.local/state/wireplumber/stream-properties. So the launcher copies that
# value into Spotify's prefs just before starting it, and Spotify then applies
# it itself. WirePlumber stores the slider value cubed, hence the cube root.
#
# WirePlumber only sees the volume while Spotify has a stream (i.e. is
# playing). A change made while paused reaches only Spotify's prefs, on a clean
# quit, so a prefs file newer than WirePlumber's record is left alone.
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
