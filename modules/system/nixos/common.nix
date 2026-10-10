# Universal NixOS settings: any host imports this.
_: {
  flake.modules.nixos.common =
    { pkgs, ... }:
    {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nixpkgs.config.allowUnfree = true;

      # Weekly GC of generations older than 30 days. (The Macs use
      # `nh clean` instead: system/darwin/nh-gc.nix.)
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      # Hard-link identical store files to reclaim disk.
      nix.optimise = {
        automatic = true;
        dates = [ "weekly" ];
      };

      # Skip openldap's tests: test017-syncreplication-refresh is flaky on
      # x86_64-linux. The override changes openldap's hash, so it and what
      # depends on it (gnupg, gpgme, …) are built locally, not fetched from
      # cache.nixos.org. Drop it once the upstream test is fixed.
      nixpkgs.overlays = [
        (_: prev: {
          openldap = prev.openldap.overrideAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
        })
      ];

      time.timeZone = "Europe/London";
      i18n.defaultLocale = "en_GB.UTF-8";

      programs.zsh.enable = true;

      environment.systemPackages = with pkgs; [
        vim
        git
        wget
      ];
    };
}
