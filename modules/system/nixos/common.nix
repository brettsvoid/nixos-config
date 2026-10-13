# Universal NixOS settings: any host imports this.
_: {
  flake.modules.nixos.common =
    { pkgs, ... }:
    {
      nix = {
        settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Weekly GC of generations older than 30 days. (The Macs use
        # `nh clean` instead: system/darwin/nh-gc.nix.)
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };

        # Hard-link identical store files to reclaim disk.
        optimise = {
          automatic = true;
          dates = [ "weekly" ];
        };
      };
      nixpkgs.config.allowUnfree = true;

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

      # /tmp starts empty at each boot. NixOS keeps it otherwise (systemd-tmpfiles
      # only removes what is 10 days old), so files from an earlier boot, pid files
      # among them, look current. Not a tmpfs: Nix builds use /tmp, and large ones
      # can outgrow it.
      boot.tmp.cleanOnBoot = true;

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
