# Hourly off-site restic backups to Backblaze B2, through B2's S3 API
# (restic's docs advise it over the native b2: backend). Each host gets its
# own repo under one bucket, so prunes never contend for locks. Hosts opt in
# by importing `backups`, and list what to back up in `backups.paths` (the
# home folder by default). Leave out what Nix rebuilds anyway.
#
# Needs two agenix secrets in nix-secrets, encrypted to every opted-in host:
#   restic-b2-env.age    AWS_ACCESS_KEY_ID=… and AWS_SECRET_ACCESS_KEY=… lines
#                        (a B2 application key for the bucket)
#   restic-password.age  the repo password (shared by every host's repo)
# The bucket needs the lifecycle rule "Keep only the last version of the
# file", or pruned packs stay hidden and billed.
#
# NixOS uses nixpkgs' services.restic. nix-darwin has no restic module, so
# the Macs get a launchd daemon running the same backup and prune. Both give
# a `restic-b2` command with the repo, password and key already set, e.g.
# `sudo restic-b2 snapshots`.
_:
let
  bucket = "brettsvoid-backups";
  endpoint = "s3.us-west-002.backblazeb2.com";
  repository = host: "s3:https://${endpoint}/${bucket}/${host}";

  # The last day hourly, then 7 dailies, 4 weeklies and 6 monthlies.
  keep = [
    "--keep-hourly 24"
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 6"
  ];

  # Anything rebuilt or re-downloaded on demand. --exclude-caches also skips
  # every directory holding a CACHEDIR.TAG, such as cargo's target/.
  excludes = home: [
    # Build output and dependency folders, wherever they are.
    "**/target"
    "**/node_modules"
    "**/.direnv"
    "**/.venv"
    "**/__pycache__"
    "**/.turbo"
    "**/.next"
    "**/.svelte-kit"
    "**/.parcel-cache"
    "**/.zig-cache"
    "**/zig-out"
    # Chromium caches, in every Chromium browser and Electron app.
    "**/CacheStorage"
    "**/Service Worker/ScriptCache"
    "**/Cache/Cache_Data"
    "**/Code Cache"
    "**/GPUCache"
    "**/OptGuideOnDeviceModel"
    "${home}/.config/google-chrome/*/Extensions"
    # Wine's own files, rebuilt in every prefix. Saves and the registry stay.
    "**/drive_c/windows"
    "**/drive_c/ProgramData/Package Cache"
    "**/drive_c/Program Files/Electronic Arts/EA Desktop"
    # Steam: the client, game installs, shader caches and Proton builds all
    # download again. Keep userdata, config and steamapps/compatdata (Proton
    # prefixes, where most saves live). The last matching pattern wins.
    "${home}/.local/share/Steam/*"
    "!${home}/.local/share/Steam/userdata"
    "!${home}/.local/share/Steam/config"
    "!${home}/.local/share/Steam/steamapps"
    "${home}/.local/share/Steam/config/htmlcache"
    "${home}/.local/share/Steam/steamapps/common"
    "${home}/.local/share/Steam/steamapps/shadercache"
    "${home}/.local/share/Steam/steamapps/downloading"
    "${home}/.local/share/Steam/steamapps/temp"
    "${home}/.local/share/Steam/steamapps/workshop"
    # Heroic game installs (its prefixes stay), and the launchers' own
    # installs in their Wine prefixes.
    "${home}/Games/Heroic/*"
    "!${home}/Games/Heroic/Prefixes"
    "${home}/Games/*/drive_c/Program Files"
    "${home}/Games/*/drive_c/Program Files (x86)"
    "${home}/.local/share/lutris/runners"
    "${home}/.local/share/lutris/runtime"
    "${home}/.local/share/umu"
    "${home}/.config/heroic/tools"
    # Fluorine, installed by the Nolvus Dashboard. The instance is in /games.
    "${home}/.local/share/fluorine"
    # Model weights, fetched again by ComfyUI-Manager or each setup script,
    # and the upstream checkouts those scripts clone.
    "${home}/ai-models"
    "${home}/comfyui/temp"
    "${home}/projects/*/weights"
    "${home}/projects/trellis2-local/src"
    "${home}/projects/unirig-local/src"
    "${home}/projects/quad-remesh/src"
    # Godot's import cache, and perf's debug-info cache.
    "**/.godot"
    "${home}/.debug"
    # Creation Club files, downloaded again by Skyrim Anniversary Edition.
    "${home}/nolvus-windows-backup/skyrim-cc"
    # Tool caches, toolchains and package stores in home.
    "${home}/.cache"
    "${home}/.cargo/registry"
    "${home}/.cargo/git"
    "${home}/.rustup"
    "${home}/.npm"
    "${home}/.gradle"
    "${home}/go/pkg"
    "${home}/.local/share/fnm"
    "${home}/.local/share/pnpm"
    "${home}/Library/pnpm"
    "${home}/Library/Caches"
    "${home}/Library/Developer"
    "${home}/.ghcup"
    "${home}/.cabal/packages"
    "${home}/.expo"
    "${home}/.vscode/extensions"
    "${home}/.docker/scout"
    "${home}/.local/share/uv"
    "${home}/.local/share/claude/versions"
    "${home}/.local/share/claude/ClaudeCode.app"
    # Plugins pinned by lazy-lock.json in this repo, and mason's LSP servers.
    "${home}/.local/share/nvim/lazy"
    "${home}/.local/share/nvim/lazy-rocks"
    "${home}/.local/share/nvim/tree-sitter-*-tmp"
    "${home}/.local/share/nvim/mason"
    "${home}/Library/Android"
    "${home}/Library/Unity/cache"
    "${home}/Library/Arduino15/packages"
    "${home}/Library/Arduino15/staging"
    "${home}/Library/Logs"
    # Docker's VM disk: sparse, 460 GB apparent, and read in full whenever
    # Docker has run. Images and containers can be pulled or built again.
    "${home}/Library/Containers/com.docker.docker"
    # App installs, models and caches kept in Application Support.
    "${home}/Library/Application Support/com.docker.install"
    "${home}/Library/Application Support/Autodesk/webdeploy"
    "${home}/Library/Application Support/Spotify/PersistentCache"
    "${home}/Library/Application Support/Local/lightning-services"
    "${home}/Library/Application Support/Steam/Steam.AppBundle"
    "${home}/Library/Application Support/Steam/appcache"
    "${home}/Library/Application Support/Code/CachedData"
    "${home}/Library/Application Support/Code/CachedExtensionVSIXs"
    # Bins.
    "${home}/.local/share/Trash"
    "${home}/.Trash"
    # iCloud Drive: not wanted, and cloud-only files fail to read.
    "${home}/Library/Mobile Documents"
  ];

  pathsOption =
    lib: home:
    lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ home ];
      description = "Absolute paths this host backs up to B2.";
    };

  secrets = inputs: {
    restic-b2-env.file = "${inputs.secrets}/restic-b2-env.age";
    restic-password.file = "${inputs.secrets}/restic-password.age";
  };
in
{
  flake.modules.nixos.backups =
    {
      config,
      flake,
      inputs,
      lib,
      ...
    }:
    let
      home = "/home/${flake.lib.username}";
    in
    {
      options.backups.paths = pathsOption lib home;

      config.age.secrets = secrets inputs;

      config.services.restic.backups.b2 = {
        repository = repository config.networking.hostName;
        environmentFile = config.age.secrets.restic-b2-env.path;
        passwordFile = config.age.secrets.restic-password.path;
        initialize = true;
        inherit (config.backups) paths;
        exclude = excludes home;
        extraBackupArgs = [ "--exclude-caches" ];
        pruneOpts = keep;
        inhibitsSleep = true;
        # Persistent: a run missed while the machine was off happens at boot.
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
        };
      };
    };

  flake.modules.darwin.backups =
    {
      config,
      flake,
      inputs,
      pkgs,
      lib,
      ...
    }:
    let
      home = "/Users/${flake.lib.username}";
      excludeFile = pkgs.writeText "restic-excludes" (lib.concatLines (excludes home));

      # Like the restic-<name> wrapper nixpkgs' NixOS module makes.
      restic-b2 = pkgs.writeShellApplication {
        name = "restic-b2";
        runtimeInputs = [ pkgs.restic ];
        text = ''
          set -a
          # shellcheck disable=SC1091
          . ${config.age.secrets.restic-b2-env.path}
          set +a
          export RESTIC_REPOSITORY="${repository config.networking.hostName}"
          export RESTIC_PASSWORD_FILE="${config.age.secrets.restic-password.path}"
          export RESTIC_CACHE_DIR=/var/root/Library/Caches/restic
          exec restic "$@"
        '';
      };

      backup = pkgs.writeShellApplication {
        name = "restic-b2-backup";
        runtimeInputs = [ restic-b2 ];
        text = ''
          # Same order as the NixOS module: init once, back up, then prune.
          restic-b2 cat config >/dev/null 2>&1 || restic-b2 init
          # Exit 3 = snapshot saved but some files unreadable (TCC); still prune.
          restic-b2 backup --exclude-caches --exclude-file ${excludeFile} ${lib.escapeShellArgs config.backups.paths} || [ $? -eq 3 ]
          restic-b2 unlock
          restic-b2 forget --prune ${lib.concatStringsSep " " keep}
        '';
      };

      # macOS grants a launchd job Full Disk Access by the program launchd
      # starts, and its children inherit it. This launcher only starts its
      # arguments and waits, so the grant goes to it, not to /bin/sh. It lives
      # at a fixed path, replaced only when its bytes change: a store path
      # would lose the grant on every update.
      launcher = pkgs.writeCBin "restic-b2-launcher" ''
        #include <spawn.h>
        #include <stdio.h>
        #include <string.h>
        #include <sys/wait.h>
        extern char **environ;
        int main(int argc, char **argv) {
          pid_t pid;
          int status, err;
          if (argc < 2) {
            fprintf(stderr, "usage: %s command [args...]\n", argv[0]);
            return 64;
          }
          err = posix_spawn(&pid, argv[1], NULL, NULL, argv + 1, environ);
          if (err) {
            fprintf(stderr, "%s: %s\n", argv[1], strerror(err));
            return 127;
          }
          if (waitpid(pid, &status, 0) < 0) {
            perror("waitpid");
            return 1;
          }
          return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
        }
      '';
      launcherPath = "/usr/local/libexec/restic-b2-launcher";
    in
    {
      options.backups.paths = pathsOption lib home;

      config = {
        age.secrets = secrets inputs;

        # restic-b2, and restic-b2-backup to run a backup by hand (both sudo).
        environment.systemPackages = [
          restic-b2
          backup
        ];

        # Before the launchd step, so the job never starts without it. A
        # rename, not an overwrite, as the old copy may be running.
        system.activationScripts.extraActivation.text = ''
          if ! /usr/bin/cmp -s ${lib.getExe launcher} ${launcherPath}; then
            if [ -e ${launcherPath} ]; then
              echo "restic-b2: the backup launcher changed: give ${launcherPath} Full Disk Access again" >&2
            fi
            /bin/mkdir -p ${dirOf launcherPath}
            /usr/bin/install -m 0755 -o root -g wheel ${lib.getExe launcher} ${launcherPath}.new
            /bin/mv -f ${launcherPath}.new ${launcherPath}
          fi
        '';

        launchd.daemons.restic-b2 = {
          serviceConfig = {
            # Root, to read the agenix secrets. Folders macOS protects with TCC
            # (Desktop, Documents, Downloads, Mail…) are skipped with warnings
            # until the launcher has Full Disk Access: System Settings ›
            # Privacy & Security › Full Disk Access › +, then ⇧⌘G and its path.
            ProgramArguments = [
              launcherPath
              "/bin/sh"
              "-c"
              # agenix writes the secrets after launchd loads this job, at
              # boot and on a switch: wait for them too. Polled, as wait4path
              # only looks again when the mount table changes, and agenix
              # writes into a disk it has already mounted.
              "/bin/wait4path /nix/store && until [ -e ${config.age.secrets.restic-b2-env.path} ] && [ -e ${config.age.secrets.restic-password.path} ]; do sleep 1; done && exec ${lib.getExe backup}"
            ];
            # Hourly, and at boot to catch up after the Mac was off. launchd
            # never starts a second copy while a run is still going.
            StartInterval = 3600;
            RunAtLoad = true;
            StandardOutPath = "/var/log/restic-b2.log";
            StandardErrorPath = "/var/log/restic-b2.log";
          };
        };
      };
    };
}
