# Universal nix-darwin settings: any Darwin host imports this.
#
# Modern nix-darwin (post-2025-ish) unconditionally manages the nix-daemon
# launchd plist whenever `nix.enable = true` (the default). On the M1 MBP
# (which already has the upstream non-Determinate daemon at
# /Library/LaunchDaemons/org.nixos.nix-daemon.plist), the first
# `darwin-rebuild switch` will replace that plist with its own. Reversible
# if needed; the worst case is a one-line config rollback + manual plist
# restore.
_: {
  flake.modules.darwin.common = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "@admin"
        "brett"
      ];
    };

    # Weekly garbage collection: delete store paths older than 30 days.
    # `interval` is a launchd StartCalendarInterval, not a systemd string.
    nix.gc = {
      automatic = true;
      interval = {
        Weekday = 7;
        Hour = 3;
        Minute = 15;
      };
      options = "--delete-older-than 30d";
    };

    # Hard-link identical store files to reclaim disk. Same weekly schedule.
    nix.optimise = {
      automatic = true;
      interval = {
        Weekday = 7;
        Hour = 3;
        Minute = 45;
      };
    };

    programs.zsh.enable = true;

    # nix-darwin requires this. Pinned at first switch; do NOT change.
    system.stateVersion = 5;

    # Touch ID for sudo.
    security.pam.services.sudo_local.touchIdAuth = true;

    nixpkgs.config.allowUnfree = true;

    # Required by nix-darwin's user-defaults migration. Identifies which
    # user owns user-scoped defaults (NSGlobalDomain, finder, dock, etc.).
    system.primaryUser = "brett";
  };
}
