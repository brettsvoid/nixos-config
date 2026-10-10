# tuigreet on greetd: a terminal login that starts Hyprland.
_: {
  flake.modules.nixos.greetd =
    { pkgs, ... }:
    {
      # Not what enables the NVIDIA driver: hardware.nvidia keys off
      # videoDrivers alone, and in that module xserver.enable only adds the
      # nvidia modules to boot.kernelModules. No X session runs here.
      services.xserver.enable = true;

      # tuigreet draws on the kernel console, where the default loglevel (4)
      # prints every KERN_ERR message over the login prompt. 3 keeps only
      # crit/alert/emerg; the journal still gets everything (`journalctl -k`).
      boot.consoleLogLevel = 3;

      # Likewise systemd's boot status lines, which land on tuigreet when a
      # unit starts after greetd (Type=idle waits only 5 s). "error" shows
      # failures only.
      boot.kernelParams = [ "systemd.show_status=error" ];

      services.greetd =
        let
          sessions = pkgs.linkFarm "greeter-sessions" [
            {
              name = "hyprland.desktop";
              path = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
            }
          ];
        in
        {
          enable = true;
          settings.default_session = {
            # pkgs.tuigreet: `pkgs.greetd` is now greetd itself, not a set
            # of greeters.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${sessions}";
            user = "greeter";
          };
        };
    };
}
