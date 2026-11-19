# Weekly Docker prune. BuildKit's own GC never capped the build cache here:
# with defaultKeepStorage the resolved policy has only a reservedSpace floor
# and no maxUsedSpace, and the cache reached 159 GB. Docker Desktop owns
# ~/.docker/daemon.json, so this prunes from outside instead.
#
#   builder: cache not *used* in 7 days.
#   images:  images no container uses, *created* over 7 days ago (`until` on
#            images is creation time), so old tyto-rust-deps tags are re-pulled.
#
# Volumes are never touched: they hold data. If Docker isn't running, both
# commands fail and that week is skipped. Docker.raw hands freed space back
# to macOS within a minute or so.
_: {
  flake.modules.homeManager.apps-docker-prune =
    { config, ... }:
    {
      launchd.agents.docker-prune = {
        enable = true;
        config = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              date
              docker builder prune --all --force --filter until=168h
              docker image prune --all --force --filter until=168h
            ''
          ];
          # Docker Desktop links its CLI into /usr/local/bin.
          EnvironmentVariables.PATH = "/usr/local/bin:/usr/bin:/bin";
          # Sundays at 04:30, after cargo-sweep. launchd runs it on wake if asleep.
          StartCalendarInterval = [
            {
              Weekday = 7;
              Hour = 4;
              Minute = 30;
            }
          ];
          ProcessType = "Background";
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/docker-prune.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/docker-prune.log";
        };
      };
    };
}
