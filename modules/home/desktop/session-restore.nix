# Reopens, at login, the apps that were open when the last session ended,
# each on its own workspace. Hyprland has no session restore of its own.
# hyprsession (github:joshurtree/hyprsession) saves the open windows every
# 60 s to ~/.local/share/hyprsession/default, and relaunches them when it
# starts. A host that imports this module gets `session-exit`, which the
# shell's power buttons call (Caelestia's session.commands in caelestia.nix).
#
# It reopens apps, not what was in them: a kitty comes back as a fresh
# shell. Firefox brings back its own windows and tabs (browser.startup.page
# in apps/firefox.nix), and as its windows share one process it is
# relaunched once. The command for each window comes from
# /proc/<pid>/cmdline. Tested on Hyprland 0.56.2: the workspace and
# floating came back, a floating window's position and size did not.
{ inputs, ... }:
{
  flake.modules.homeManager.desktop-session-restore =
    { pkgs, ... }:
    let
      hyprsession = inputs.hyprsession.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # `session-exit poweroff|reboot|logout`. The power buttons used to call
      # logind directly, which ends the session without asking the apps to
      # close, so Firefox and the like could not save their state.
      # hyprshutdown, as Hyprland's wiki recommends, closes each window and
      # waits for its app to exit before Hyprland exits, then runs the post
      # command. It also SIGTERMs every process Hyprland started, hyprsession
      # among them, so a periodic save landing while windows close would
      # record only part of the session. Hence hyprsession is stopped and
      # saves once more, with every window still open, before hyprshutdown
      # starts. hyprshutdown's Cancel button leaves Hyprland running, but
      # by then apps have been asked to close and hyprsession is gone until
      # the next login.
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

      # With no arguments hyprsession loads the session named "default",
      # then saves over it every 60 s. Loading first kills every open
      # window's process and waits until no windows are left. At login
      # nothing else this config starts has a window yet (the shell's
      # panels are layer surfaces, not windows), so there is nothing to
      # kill. Do not start it by hand in a running session.
      wayland.windowManager.hyprland.settings.exec-once = [ "hyprsession" ];
    };
}
