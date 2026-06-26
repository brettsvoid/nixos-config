# Garbage collection via `nh clean all`, run weekly as root through launchd.
# This REPLACES nix-darwin's nix.gc (removed from common.nix). `nh clean` is
# a strict superset of nix-collect-garbage: it prunes generations AND sweeps
# stale gcroots — including the nix-direnv roots that `nix-collect-garbage`
# never touches, the main source of store bloat for a direnv user.
#
# Policy: keep at least 5 generations AND anything newer than 30 days
# (`--keep 5 --keep-since 30d`). Because this is the SINGLE retention policy
# on the system profile there is no age-vs-count conflict — running it next
# to `nix-collect-garbage --delete-older-than` would let the age pass delete
# generations the count wanted to keep. Store optimisation stays separate in
# common.nix (nix.optimise); nh clean does not hard-link.
_: {
  flake.modules.darwin.nh-gc =
    { pkgs, ... }:
    {
      launchd.daemons.nh-clean = {
        serviceConfig = {
          # Runs as root (launchd daemon), which `nh clean all` needs to
          # touch the system profile; already root, so it never self-elevates
          # or prompts.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${pkgs.nh}/bin/nh clean all --keep 5 --keep-since 30d"
          ];
          EnvironmentVariables = {
            # nh shells out to `nix` / `nix-store`; the daemon's PATH is bare,
            # so point it at the multi-user nix profile where they live.
            PATH = "/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
            # Skip nh's interactive startup checks (nix version / experimental
            # features) — pointless and fragile in a non-interactive daemon.
            NH_NO_CHECKS = "1";
          };
          # launchd StartCalendarInterval (not a systemd string). Weekly,
          # Sunday 03:15 — the slot nix.gc used to occupy.
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
