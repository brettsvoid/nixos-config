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
  flake.modules.darwin.common =
    { flake, ... }:
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "@admin"
          flake.lib.username
        ];
      };

      # Garbage collection is handled by `nh clean all` (a strict superset of
      # nix-collect-garbage — it also prunes stale gcroots / nix-direnv roots)
      # in modules/system/darwin/nh-gc.nix. Kept out of here so there is a
      # single GC retention policy on the system profile.

      # Hard-link identical store files to reclaim disk. Weekly, alongside GC.
      nix.optimise = {
        automatic = true;
        interval = {
          Weekday = 7;
          Hour = 3;
          Minute = 45;
        };
      };

      programs.zsh.enable = true;

      # Don't run compinit from the generated /etc/zshrc. oh-my-zsh already
      # runs its own (`compinit -i -d $ZSH_COMPDUMP`), so the system one was
      # pure duplication: two compinit runs and two compaudit scans over
      # /opt/homebrew/share/zsh/site-functions on every interactive shell.
      # Measured at 0.171s of a 2.05s startup. This is exactly the case the
      # option's own docs describe — a local config with a custom fpath and
      # its own compinit call.
      #
      # enableGlobalCompInit, NOT enableCompletion: the latter also drops
      # pkgs.nix-zsh-completions from systemPackages, which we still want.
      # enableBashCompletion defaults to enableCompletion, so /etc/zshrc
      # keeps calling bashcompinit — safe before compinit, because
      # bashcompinit only *defines* complete/compgen, and the compdef call
      # lives inside the complete() wrapper that runs later.
      programs.zsh.enableGlobalCompInit = false;

      # nix-darwin requires this. Pinned at first switch; do NOT change.
      system.stateVersion = 5;

      # Touch ID for sudo.
      security.pam.services.sudo_local.touchIdAuth = true;

      nixpkgs.config.allowUnfree = true;

      # Required by nix-darwin's user-defaults migration. Identifies which
      # user owns user-scoped defaults (NSGlobalDomain, finder, dock, etc.).
      system.primaryUser = flake.lib.username;
    };
}
