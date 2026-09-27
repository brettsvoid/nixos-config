# tuigreet on top of greetd, providing a Hyprland Wayland session.
# Replaces GDM/GNOME with a minimal terminal-based login.
_: {
  flake.modules.nixos.greetd =
    { pkgs, ... }:
    {
      # Needed for services.xserver.videoDrivers (NVIDIA module). xserver itself
      # is not used as a session; Hyprland is Wayland.
      services.xserver.enable = true;

      # tuigreet draws on the kernel console, and at the default loglevel (4)
      # every KERN_ERR message is printed straight over it. On brett-desktop
      # a failing USB port logs one every ~16 s for two minutes after boot,
      # which scrambled the login prompt. 3 keeps only crit/alert/emerg on
      # the console; everything still reaches the journal (`journalctl -k`).
      boot.consoleLogLevel = 3;

      # Same console, from systemd: its boot status lines ("Starting Docker
      # Application Container Engine…") land on top of tuigreet whenever a
      # unit starts after greetd. nixpkgs runs greetd as Type=idle, but idle
      # only waits up to 5 s for other jobs; docker came 6 s later.
      # "error" keeps failures visible and silences the rest (systemd(1)).
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
            # pkgs.tuigreet, not pkgs.greetd.tuigreet: nixpkgs moved tuigreet to
            # the top level between the 2026-05-07 and 2026-07-27 revs, and
            # `pkgs.greetd` is now the greetd derivation itself rather than an
            # attrset of the greeters.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${sessions}";
            user = "greeter";
          };
        };
    };
}
