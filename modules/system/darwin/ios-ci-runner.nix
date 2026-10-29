# Tyto's iOS simulator e2e runner (irj-io/tyto#526, built by #548). A GitHub
# runner labelled only `tyto-ios` runs as its own standard user, `tyto-ci`.
# Any job runs arbitrary code, Dependabot bumps included, and the separate
# user keeps it away from brett's AWS session, Docker credentials, SSH agent
# and Keychain. tyto-ci joins `staff`, as every macOS user does, so brett's
# home goes 700 below; it was 750 with group staff.
#
# The runner is nix-darwin's launchd daemon, and that is enough: a job booted
# a simulator and Maestro drove it with no tyto-ci login (#548), so tyto-ci
# never logs in and stays hidden.
#
# A runner that has never registered reads a registration token from
# `tokenFile` once. The registration then persists in
# /var/lib/github-runners/<name>, and the token file can go. Setup, reboots
# and failover: docs/CI.md in the tyto repo.
_: {
  flake.modules.darwin.ios-ci-runner =
    {
      lib,
      pkgs,
      flake,
      ...
    }:
    let
      user = "tyto-ci";
      home = "/Users/${user}";
      runner = "brett-mac-mini-ios";
      workDir = "/private/var/lib/github-runners/_work/${runner}";

      # CI's own Xcode, beside the workstation's, so updating
      # /Applications/Xcode.app never changes CI. Bump it on purpose, after
      # apps/mobile-e2e/scripts/check-ios-driver.sh passes on the new one.
      xcode = {
        version = "26.2";
        build = "17C52";
      };
      xcodeApp = "/Applications/Xcode-${xcode.version}.app";
      developerDir = "${xcodeApp}/Contents/Developer";

      # Caps tyto-ci's caches at about 30 GB, deleting the cheapest to rebuild
      # first. A job keeps its simulator and build products while it runs, so a
      # week with a job running is skipped.
      cacheCleanup = pkgs.writeShellApplication {
        name = "tyto-ci-cache-cleanup";
        text = ''
          cap_kb=$((30 * 1024 * 1024))

          if /usr/bin/pgrep -u ${user} -f Runner.Worker >/dev/null; then
            echo "$(date): a job is running, skipped"
            exit 0
          fi

          caches=(
            ${home}/Library/Developer/Xcode/DerivedData
            ${home}/Library/Developer/CoreSimulator/Devices
            ${workDir}
            ${home}/Library/Caches/CocoaPods
            ${home}/Library/pnpm/store
            ${home}/.maestro/tests
          )

          size_kb() {
            local total=0 dir kb
            for dir in "''${caches[@]}"; do
              if [[ -e $dir ]]; then
                kb=$(du -sk "$dir" 2>/dev/null | cut -f1) || true
                total=$((total + ''${kb:-0}))
              fi
            done
            echo "$total"
          }

          total=$(size_kb)
          echo "$(date): caches hold $((total / 1024 / 1024)) GB"
          for dir in "''${caches[@]}"; do
            ((total > cap_kb)) || break
            [[ -e $dir ]] || continue
            if [[ $dir == */CoreSimulator/Devices ]]; then
              # Simulators belong to simctl's device set; deleting their
              # folders would leave it pointing at nothing.
              DEVELOPER_DIR=${developerDir} xcrun simctl delete all || echo "simctl delete all failed"
            else
              find "$dir" -mindepth 1 -delete || echo "could not clear all of $dir"
            fi
            total=$(size_kb)
            echo "cleared $dir, $((total / 1024 / 1024)) GB left"
          done
        '';
      };
    in
    {
      users.knownUsers = [ user ];
      users.users.${user} = {
        uid = 502;
        gid = 20;
        inherit home;
        createHome = true;
        shell = "/bin/zsh";
        description = "Tyto CI";
      };

      # The display may sleep; the system must not, or the runner drops off.
      power = {
        sleep.computer = "never";
        restartAfterPowerFailure = true;
      };

      services.github-runners.${runner} = {
        enable = true;
        url = "https://github.com/irj-io/tyto";
        tokenFile = "/etc/tyto-ci/registration-token";
        inherit user;
        group = "staff";
        extraLabels = [ "tyto-ios" ];
        noDefaultLabels = true;
        replace = true;
        extraPackages = [ pkgs.jdk17 ];
        extraEnvironment = {
          # The module's default is the runner's state directory. tyto-ci's
          # home is where DerivedData, the pnpm store and Maestro persist.
          HOME = home;
          DEVELOPER_DIR = developerDir;
          JAVA_HOME = "${pkgs.jdk17.home}";
        };
        # Standard, not Background: Background confines the process to the
        # efficiency cores and throttles its disk I/O. Nice 10 lets the
        # workstation win when the two overlap.
        serviceOverrides = {
          Nice = 10;
          ProcessType = lib.mkForce "Standard";
          # The module means to set KeepAlive, but merges an mkIf into it with
          # `//`, so the plist gets none and an exited runner stays down.
          KeepAlive = lib.mkForce true;
        };
      };

      # The module's PATH holds only Nix packages. Jobs need the system's own
      # tools too: xcrun, xcodebuild, python3, defaults.
      launchd.daemons."github-runner-${runner}".path = lib.mkAfter [
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];

      launchd.daemons.tyto-ci-cache-cleanup.serviceConfig = {
        ProgramArguments = [ "${cacheCleanup}/bin/tyto-ci-cache-cleanup" ];
        UserName = user;
        GroupName = "staff";
        # Sundays at 05:00, after the 02:00 nightly e2e.
        StartCalendarInterval = [
          {
            Weekday = 7;
            Hour = 5;
            Minute = 0;
          }
        ];
        RunAtLoad = false;
        StandardOutPath = "/var/log/tyto-ci-cache-cleanup.log";
        StandardErrorPath = "/var/log/tyto-ci-cache-cleanup.log";
      };

      system.activationScripts.postActivation.text = ''
        # iOS CI runner (ios-ci-runner.nix)
        chmod 700 /Users/${flake.lib.username}

        xcode_build() {
          /usr/libexec/PlistBuddy -c 'Print :ProductBuildVersion' "$1/Contents/version.plist" 2>/dev/null || true
        }
        if [ "$(xcode_build ${xcodeApp})" != "${xcode.build}" ]; then
          if [ ! -e ${xcodeApp} ] && [ "$(xcode_build /Applications/Xcode.app)" = "${xcode.build}" ]; then
            echo "[ios-ci-runner] cloning /Applications/Xcode.app to ${xcodeApp}..." >&2
            /usr/bin/ditto --clone /Applications/Xcode.app ${xcodeApp}
            # Without the receipt, the App Store doesn't update the pinned copy.
            rm -rf ${xcodeApp}/Contents/_MASReceipt
          else
            echo "[ios-ci-runner] warning: CI wants Xcode ${xcode.version} (${xcode.build}) at ${xcodeApp}; see docs/CI.md in the tyto repo" >&2
          fi
        fi

        mkdir -p /etc/tyto-ci
        chown ${user}:staff /etc/tyto-ci
        chmod 700 /etc/tyto-ci
      '';
    };
}
