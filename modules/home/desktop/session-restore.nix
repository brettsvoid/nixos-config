# Reopens, at login, the apps that were open when the last session ended,
# each on the workspace it was on; Hyprland has no session restore of its
# own. hyprsession (github:joshurtree/hyprsession) saves the open windows
# every 60 s to ~/.local/share/hyprsession/default and relaunches them when
# it starts. A host that imports this module gets `session-exit`, which the
# shell's power buttons call (Caelestia's session.commands in caelestia.nix).
#
# It reopens apps, not what was in them: a kitty comes back as a fresh
# shell. Firefox restores its own windows and tabs (browser.startup.page in
# apps/firefox.nix) and, as its windows share one process, is relaunched
# once. Each window's command comes from /proc/<pid>/cmdline. A floating
# window comes back floating, but not at its old position or size.
{ inputs, ... }:
{
  flake.modules.homeManager.desktop-session-restore =
    { pkgs, ... }:
    let
      # hyprsession saves each window's monitor by Hyprland's monitor ID, and
      # for 60 s after relaunching moves each window's whole workspace to that
      # ID. Hyprland gives a monitor the lowest free ID when it connects, so
      # IDs change between logins and workspaces landed on the wrong monitor.
      # The patch drops the monitor; each host's workspace rules already put
      # every workspace on its monitor.
      hyprsession =
        inputs.hyprsession.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [ ./session-restore/no-monitor-ids.patch ];
          });

      # `session-exit poweroff|reboot|logout`. Calling logind directly ends the
      # session without asking apps to close, so Firefox and the like cannot
      # save their state. hyprshutdown (as Hyprland's wiki recommends) closes
      # each window and waits for its app to exit before Hyprland exits, then
      # runs the post command. It also SIGTERMs everything Hyprland started,
      # hyprsession included, and a periodic save while windows close would
      # record only part of the session: so hyprsession is stopped and saves
      # once more first. hyprshutdown's Cancel leaves Hyprland running, but
      # apps have been asked to close and hyprsession is gone until next login.
      session-exit = pkgs.writeShellApplication {
        name = "session-exit";
        # systemctl, and the `which` and `kill` hyprsession calls, come from
        # the system profile.
        runtimeInputs = [
          hyprsession
          pkgs.coreutils
          pkgs.hyprshutdown
          pkgs.procps
        ];
        text = ''
          case "''${1:-}" in
            poweroff) label="Shutting down..." post="systemctl poweroff" ;;
            reboot) label="Restarting..." post="systemctl reboot" ;;
            logout) label="Logging out..." post="" ;;
            *)
              echo "Usage: session-exit {poweroff|reboot|logout}" >&2
              exit 2
              ;;
          esac

          pkill -x hyprsession || true
          for _ in $(seq 20); do
            pgrep -x hyprsession >/dev/null || break
            sleep 0.1
          done
          # A failed save must not stop the shutdown.
          hyprsession save || echo "session-exit: could not save the session" >&2

          args=(--top-label "$label")
          if [ -n "$post" ]; then
            args+=(--post-cmd "$post")
          fi
          exec hyprshutdown "''${args[@]}"
        '';
      };
    in
    {
      home.packages = [
        hyprsession
        session-exit
      ];

      # With no arguments hyprsession loads the session named "default", then
      # saves over it every 60 s. Loading first kills every open window's
      # process. At login nothing else has a window yet (the shell's panels are
      # layer surfaces), but do not start it by hand in a running session.
      wayland.windowManager.hyprland.settings.exec-once = [ "hyprsession" ];
    };
}
