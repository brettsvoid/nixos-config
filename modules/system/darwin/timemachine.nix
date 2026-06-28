# Disable Time Machine. This Mac's backup of record is Arq; there is no
# spare disk for a Time Machine destination, and none is configured — so TM
# never produces a usable backup, it only wakes `backupd` to poll/retry.
# Setting AutoBackup=0 stops that churn.
#
# nix-darwin has no native Time Machine option (verified against the pinned
# rev), so we do it from an activation script. `tmutil disable` is idempotent
# and writes AutoBackup=0 to /Library/Preferences/com.apple.TimeMachine.plist;
# we guard on the current value so the switch stays a no-op once it's off.
#
# Caveat: on recent macOS, `tmutil disable` requires the calling process to
# have Full Disk Access. This runs as root during `darwin-rebuild switch`; if
# the terminal driving the switch lacks FDA the command fails harmlessly and
# we log a warning rather than aborting activation. In that case, grant the
# terminal Full Disk Access once, or flip it by hand in System Settings →
# General → Time Machine.
_: {
  flake.modules.darwin.timemachine = {
    system.activationScripts.postActivation.text = ''
      # ─── Disable Time Machine (Arq is the backup of record) ───────────
      if [ "$(/usr/bin/defaults read /Library/Preferences/com.apple.TimeMachine.plist AutoBackup 2>/dev/null)" != "0" ]; then
        echo "[timemachine] disabling automatic backups..." >&2
        /usr/bin/tmutil disable 2>/dev/null \
          || echo "[timemachine] warning: 'tmutil disable' failed — grant the terminal Full Disk Access or disable TM manually" >&2
      fi
    '';
  };
}
