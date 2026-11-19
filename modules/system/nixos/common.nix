# Universal NixOS settings: any host imports this.
_: {
  flake.modules.nixos.common =
    { pkgs, ... }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          # The NixOS CUDA team's cache: CUDA builds (Blender, for apps-blender)
          # that cache.nixos.org does not carry. Key from wiki.nixos.org/wiki/CUDA,
          # checked against the cache's own narinfo signatures.
          substituters = [ "https://cache.nixos-cuda.org" ];
          trusted-public-keys = [
            "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
          ];
        };

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
