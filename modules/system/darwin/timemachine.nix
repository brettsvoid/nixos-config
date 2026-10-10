# Disable Time Machine. Neither Mac has a destination configured (the MBP
# backs up with Arq, the mini with Borg), so it only wakes `backupd` to
# poll. nix-darwin has no Time Machine option, hence the activation script;
# it does nothing once AutoBackup is 0.
#
# `tmutil disable` needs Full Disk Access on recent macOS. If the terminal
# running the switch lacks it, activation only warns: grant the terminal
# Full Disk Access, or turn Time Machine off in System Settings.
_: {
  flake.modules.darwin.timemachine = {
    system.activationScripts.postActivation.text = ''
      # ─── Disable Time Machine ─────────────────────────────────────────
      if [ "$(/usr/bin/defaults read /Library/Preferences/com.apple.TimeMachine.plist AutoBackup 2>/dev/null)" != "0" ]; then
        echo "[timemachine] disabling automatic backups..." >&2
        /usr/bin/tmutil disable 2>/dev/null \
          || echo "[timemachine] warning: 'tmutil disable' failed — grant the terminal Full Disk Access or disable TM manually" >&2
      fi
    '';
  };
}
