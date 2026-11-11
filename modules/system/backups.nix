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
# the Macs get a launchd daemon running the same backup and prune.
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
    # Bins.
    "${home}/.local/share/Trash"
    "${home}/.Trash"
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

      backup = pkgs.writeShellApplication {
        name = "restic-b2-backup";
        runtimeInputs = [ pkgs.restic ];
        text = ''
          set -a
          # shellcheck disable=SC1091
          . ${config.age.secrets.restic-b2-env.path}
          set +a
          export RESTIC_REPOSITORY="${repository config.networking.hostName}"
          export RESTIC_PASSWORD_FILE="${config.age.secrets.restic-password.path}"
          export RESTIC_CACHE_DIR=/var/root/Library/Caches/restic

          # Same order as the NixOS module: init once, back up, then prune.
          restic cat config >/dev/null 2>&1 || restic init
          # Exit 3 = snapshot saved but some files unreadable (TCC); still prune.
          restic backup --exclude-caches --exclude-file ${excludeFile} ${lib.escapeShellArgs config.backups.paths} || [ $? -eq 3 ]
          restic unlock
          restic forget --prune ${lib.concatStringsSep " " keep}
        '';
      };
    in
    {
      options.backups.paths = pathsOption lib home;

      config = {
        age.secrets = secrets inputs;

        # Also on PATH, to run a backup by hand: sudo restic-b2-backup
        environment.systemPackages = [ backup ];

        launchd.daemons.restic-b2 = {
          serviceConfig = {
            # Root, to read the agenix secrets. Folders macOS protects with TCC
            # (Desktop, Documents, Downloads, Mail…) are skipped with warnings
            # unless restic is given Full Disk Access.
            ProgramArguments = [
              "/bin/sh"
              "-c"
              # agenix writes the secrets after launchd loads this job, at
              # boot and on a switch: wait for them too.
              "/bin/wait4path /nix/store && /bin/wait4path ${config.age.secrets.restic-b2-env.path} && /bin/wait4path ${config.age.secrets.restic-password.path} && exec ${lib.getExe backup}"
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
