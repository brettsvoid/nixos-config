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

      # Workaround: openldap's test017-syncreplication-refresh is flaky
      # and intermittently fails on x86_64-linux. openldap arrives as a
      # transitive build dep of GTK theme stack (gnome-themes-extra ⇒
      # gnome-keyring ⇒ openldap). When cache.nixos.org has built it we
      # never see this; on fresh nixpkgs revisions before the cache
      # catches up, the test runs locally and sometimes fails.
      # Drop this when the upstream test stabilizes.
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

      # Always-installed system packages
      environment.systemPackages = with pkgs; [
        vim
        git
        wget
      ];
    };
}
