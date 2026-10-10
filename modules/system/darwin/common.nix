# Universal nix-darwin settings: any Darwin host imports this.
#
# nix.enable stays at its default (true), so nix-darwin manages the
# nix-daemon. That needs upstream Nix, not Determinate: see bootstrap.sh.
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

      # No nix.gc: nh-gc.nix runs `nh clean all` instead, and two GC
      # policies would fight over which generations to keep.

      # Hard-link identical store files. Weekly, half an hour after GC.
      nix.optimise = {
        automatic = true;
        interval = {
          Weekday = 7;
          Hour = 3;
          Minute = 45;
        };
      };

      programs.zsh.enable = true;

      # No compinit in /etc/zshrc: oh-my-zsh runs its own, and a second run
      # (with its compaudit scan) slowed every shell's startup.
      # enableGlobalCompInit rather than enableCompletion, which would also
      # drop pkgs.nix-zsh-completions. /etc/zshrc still calls bashcompinit
      # (enableBashCompletion), which is safe before compinit: it only
      # defines complete/compgen.
      programs.zsh.enableGlobalCompInit = false;

      # Pinned at the first switch; don't change it.
      system.stateVersion = 5;

      # Touch ID for sudo.
      security.pam.services.sudo_local.touchIdAuth = true;

      nixpkgs.config.allowUnfree = true;

      # The user that user-scoped options (system.defaults.dock, …) apply to.
      system.primaryUser = flake.lib.username;
    };
}
