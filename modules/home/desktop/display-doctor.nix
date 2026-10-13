# display-doctor: is VRR on, monitor by monitor, and if not, why not.
#
# Three things have to line up. The monitor has to advertise Adaptive-Sync: the
# driver's vrr_capable on its DRM connector, which NVIDIA and i915 both take from the
# DisplayPort flag MSA_TIMING_PAR_IGNORED. Hyprland's misc:vrr has to allow it: 2 and 3
# turn it on only while a window is truly fullscreen, not maximised. And the frame
# rate has to stay inside the monitor's range, the EDID's range limits.
#
# The Odyssey G5 has stopped advertising Adaptive-Sync with the setting still On in its
# menu; turning it off and on there brought it back (13 October 2026).
{ config, ... }:
let
  inherit (config.flake.lib) liveHyprland;
in
{
  flake.modules.homeManager.desktop-display-doctor =
    { pkgs, ... }:
    let
      display-doctor = pkgs.writeShellApplication {
        name = "display-doctor";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.drm_info
          pkgs.gnugrep
          pkgs.jq
        ];
        text = ''
          ${liveHyprland pkgs}
          drm=$(drm_info -j 2>/dev/null)
          monitors=$(hyprctl monitors -j)
          clients=$(hyprctl clients -j)
          setting=$(hyprctl getoption misc:vrr -j | jq -r '.int')

          # The vertical range from the base EDID's range limits descriptor (tag 0xFD),
          # as "min max". Byte 4's low bits add 255 to the max (bit 1) and min (bit 0).
          edid_range() {
            local -a b
            read -r -a b <<<"$(od -An -v -tu1 -N128 "$1" | tr -s ' \n' ' ')"
            for d in 54 72 90 108; do
              if [ "''${b[d]:-1}" = 0 ] && [ "''${b[d+1]:-1}" = 0 ] && [ "''${b[d+3]:-0}" = 253 ]; then
                echo "$(( b[d+5] + (b[d+4] & 1 ? 255 : 0) )) $(( b[d+6] + (b[d+4] & 2 ? 255 : 0) ))"
                return
              fi
            done
          }

          case "$setting" in
            0) echo "Hyprland misc:vrr = 0: VRR is off on every monitor." ;;
            1) echo "Hyprland misc:vrr = 1: VRR is always on." ;;
            2) echo "Hyprland misc:vrr = 2: VRR turns on while a window is fullscreen." ;;
            3) echo "Hyprland misc:vrr = 3: VRR turns on while a game or video is fullscreen." ;;
          esac

          for dir in /sys/class/drm/card*-*; do
            [ "$(cat "$dir/status" 2>/dev/null)" = connected ] || continue
            base=''${dir##*/}
            card=''${base%%-*}
            name=''${base#*-}
            capable=$(jq -r --arg card "/dev/dri/$card" --argjson id "$(cat "$dir/connector_id")" \
              '[.[$card].connectors[] | select(.id == $id) | .properties.vrr_capable.value][0] // 0' <<<"$drm")
            min="" max=""
            read -r min max < <(edid_range "$dir/edid") || true
            mon=$(jq -c --arg n "$name" '.[] | select(.name == $n)' <<<"$monitors")

            echo
            if [ -z "$mon" ]; then
              echo "$name (not used by Hyprland)"
            else
              printf '%s  %s  %sx%s @ %.2f Hz\n' "$name" "$(jq -r '.model' <<<"$mon")" \
                "$(jq -r '.width' <<<"$mon")" "$(jq -r '.height' <<<"$mon")" "$(jq -r '.refreshRate' <<<"$mon")"
            fi
            [ -n "$min" ] && echo "  VRR range:              $min-$max Hz"
            if [ "$capable" = 1 ]; then
              echo "  Monitor advertises VRR: yes"
            else
              echo "  Monitor advertises VRR: no"
              echo "  -> Turn Adaptive-Sync on in the monitor's menu. If it is already on, turn it"
              echo "     off and on again: the Odyssey G5 sometimes stops advertising it."
              continue
            fi
            [ -n "$mon" ] || continue

            if [ "$(jq -r '.vrr' <<<"$mon")" = true ]; then
              echo "  VRR on now:             yes"
              [ -n "$min" ] && echo "  -> Working. Below $min fps the monitor leaves its VRR range."
              continue
            fi
            echo "  VRR on now:             no"

            # The window that fills this monitor's workspace: fullscreen 1 is maximised, 2 is fullscreen.
            ws=$(jq -r '.activeWorkspace.id' <<<"$mon")
            full=$(jq -r --argjson ws "$ws" \
              '[.[] | select(.workspace.id == $ws and .fullscreen > 0)][0] // empty | "\(.fullscreen) \(.class)"' <<<"$clients")
            read -r mode class <<<"''${full:-0 none}"
            case "$setting:$mode" in
              0:*) echo "  -> Set misc:vrr in hyprland.nix to turn VRR on." ;;
              1:*) echo "  -> Hyprland asked for VRR and the output refused: look for \"does not accept VRR\" in its log." ;;
              *:0) echo "  -> Nothing is fullscreen on workspace $ws. VRR turns on when a window is (Super+F)." ;;
              *:1) echo "  -> $class is maximised, not fullscreen. VRR needs true fullscreen (Super+F)." ;;
              3:2) echo "  -> $class is fullscreen, but misc:vrr 3 needs it to mark itself as a game or video." ;;
              *) echo "  -> $class is fullscreen, but VRR is off: look for a no_vrr window rule, then for \"does not accept VRR\" in Hyprland's log." ;;
            esac
          done
        '';
      };
    in
    {
      home.packages = [ display-doctor ];
    };
}
