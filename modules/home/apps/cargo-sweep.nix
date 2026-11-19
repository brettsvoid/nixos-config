# Weekly cargo-sweep over ~/projects: deletes Rust build files no build has
# used in 7 days, from every target/ folder under it (worktrees included).
# It only deletes hashed intermediates (deps/foo-<hash>, .fingerprint,
# build, incremental), never a finished binary such as target/release/bws.
#
# "Used" is the access time of each .fingerprint file, so anything that
# reads target/ wholesale resets the clock. Backups skip target/ (see
# system/backups.nix), and `cargo sweep --installed` reads every fingerprint.
_: {
  flake.modules.homeManager.apps-cargo-sweep =
    { config, pkgs, ... }:
    {
      launchd.agents.cargo-sweep = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.cargo-sweep}/bin/cargo-sweep"
            "sweep"
            "--recursive"
            "--time"
            "7"
            "${config.home.homeDirectory}/projects"
          ];
          # It runs `cargo metadata` to find each target/ folder; rustup is a
          # Homebrew install on both Macs.
          EnvironmentVariables.PATH = "/opt/homebrew/opt/rustup/bin:/usr/bin:/bin";
          # Sundays at 04:00, after nh-clean. launchd runs it on wake if asleep.
          StartCalendarInterval = [
            {
              Weekday = 7;
              Hour = 4;
              Minute = 0;
            }
          ];
          ProcessType = "Background";
          LowPriorityIO = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/cargo-sweep.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/cargo-sweep.log";
        };
      };
    };
}
