# Weekly garbage collection via `nh clean all`, as root through launchd, in
# place of nix-darwin's nix.gc. Unlike nix-collect-garbage it also sweeps
# stale gcroots, such as nix-direnv's. Keeps at least 5 generations and
# anything newer than 30 days. Don't add nix.gc alongside it: its age pass
# would delete generations this keeps. Store optimisation is nix.optimise
# in common.nix.
_: {
  flake.modules.darwin.nh-gc =
    { pkgs, ... }:
    {
      launchd.daemons.nh-clean = {
        serviceConfig = {
          # A daemon, so root: `nh clean all` needs it for the system
          # profile, and never has to prompt.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${pkgs.nh}/bin/nh clean all --keep 5 --keep-since 30d"
          ];
          EnvironmentVariables = {
            # nh runs `nix`/`nix-store`, which the daemon's bare PATH lacks.
            PATH = "/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
            # Skip nh's startup checks (nix version, experimental features).
            NH_NO_CHECKS = "1";
          };
          # Sundays at 03:15.
          StartCalendarInterval = [
            {
              Weekday = 7;
              Hour = 3;
              Minute = 15;
            }
          ];
          RunAtLoad = false;
          StandardOutPath = "/var/log/nh-clean.log";
          StandardErrorPath = "/var/log/nh-clean.log";
        };
      };
    };
}
