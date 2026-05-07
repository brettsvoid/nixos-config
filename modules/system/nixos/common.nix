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
