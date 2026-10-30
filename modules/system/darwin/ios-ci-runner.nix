# Tyto's iOS simulator e2e runner (irj-io/tyto#526, built by #548). A GitHub
# runner labelled only `tyto-ios` runs as its own standard user, `tyto-ci`.
# Any job runs arbitrary code, Dependabot bumps included, and the separate
# user keeps it away from brett's AWS session, Docker credentials, SSH agent
# and Keychain. tyto-ci joins `staff`, as every macOS user does, so brett's
# home goes 700 below; it was 750 with group staff.
#
# The runner is a launchd daemon, and that is enough: a job booted a simulator
# and Maestro drove it with no tyto-ci login (#548), so tyto-ci never logs in
# and stays hidden.
#
# It is GitHub's own runner, which updates itself, as the beelinks' does
# (#709). nix-darwin's services.github-runners runs nixpkgs' copy with
# --disableupdate, and GitHub stops sending jobs to a runner 30 days after any
# newer release, which nixpkgs can't be relied on to keep up with. The pinned
# copy below only seeds an empty directory.
#
# A runner that has never registered reads a registration token from
# `tokenFile`. The registration then persists in the runner's directory, and
# the token file can go. Setup, reboots and failover: docs/CI.md in the tyto
# repo.
_: {
  flake.modules.darwin.ios-ci-runner =
    { pkgs, flake, ... }:
    let
      user = "tyto-ci";
      home = "/Users/${user}";
      runner = "brett-mac-mini-ios";
      runnerDir = "${home}/actions-runner";
      workDir = "${runnerDir}/_work";
      logDir = "/var/log/tyto-ci";
      tokenFile = "/etc/tyto-ci/registration-token";

      seed = pkgs.fetchurl {
        url = "https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-osx-arm64-2.338.2.tar.gz";
        sha256 = "25a065af409ffa317ab4d5a3b614dd15fc9c40f2172bc1b35a1b1258e919a388";
      };

      startRunner = pkgs.writeShellApplication {
        name = "tyto-ci-runner";
        text = ''
          mkdir -p ${runnerDir}
          cd ${runnerDir}

          if [[ ! -x bin/Runner.Listener ]]; then
            echo "seeding the runner from ${seed.name}"
            /usr/bin/tar -xzf ${seed}
          fi

          if [[ ! -f .runner ]]; then
            token=""
            if [[ -r ${tokenFile} ]]; then
              token=$(tr -d '\n' <${tokenFile})
            fi
            if [[ -z $token ]]; then
              echo "not registered, and no token in ${tokenFile}: see docs/CI.md in the tyto repo" >&2
              exit 1
            fi
            ./config.sh --unattended --replace \
              --url https://github.com/irj-io/tyto \
              --token "$token" \
              --name ${runner} \
              --labels tyto-ios --no-default-labels \
              --work ${workDir}
          fi

          # env.sh snapshots PATH into .path and JAVA_HOME and the like into
          # .env, and jobs get both. It only adds what .env lacks, so start
          # without one, or a store path from an older switch would stick.
          rm -f .env
          ./env.sh

          # run.sh relaunches the listener after a self-update.
          exec ./run.sh
        '';
      };

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

      launchd.daemons.tyto-ci-runner = {
        command = "${startRunner}/bin/tyto-ci-runner";
        # bash 5 and GNU coreutils first, then the system's own tools, which
        # jobs need too: xcrun, xcodebuild, python3, defaults.
        path = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.gnutar
          pkgs.gzip
          pkgs.jdk17
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
        environment = {
          # Where DerivedData, the pnpm store and Maestro persist.
          HOME = home;
          DEVELOPER_DIR = developerDir;
          JAVA_HOME = "${pkgs.jdk17.home}";
        };
        serviceConfig = {
          UserName = user;
          GroupName = "staff";
          WorkingDirectory = home;
          RunAtLoad = true;
          # Also retries every 30 s while the runner waits for a token.
          KeepAlive = true;
          ThrottleInterval = 30;
          # Standard, not Background: Background confines the process to the
          # efficiency cores and throttles its disk I/O. Nice 10 lets the
          # workstation win when the two overlap.
          Nice = 10;
          ProcessType = "Standard";
          StandardOutPath = "${logDir}/runner.log";
          StandardErrorPath = "${logDir}/runner.log";
        };
      };

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
        StandardOutPath = "${logDir}/cache-cleanup.log";
        StandardErrorPath = "${logDir}/cache-cleanup.log";
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

        mkdir -p /etc/tyto-ci ${logDir}
        chown ${user}:staff /etc/tyto-ci ${logDir}
        chmod 700 /etc/tyto-ci
        chmod 750 ${logDir}
      '';
    };
}
