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
          # The stock session file, but with start-hyprland's output going to the
          # journal (`journalctl -t hyprland`). On tty1 the restarted Hyprland
          # draws over it, which lost the exit reason of the 1 Nov crash.
          # greetd is X-RestartIfChanged=false: edits here apply only after
          # `systemctl restart greetd` or a reboot.
          #
          # shortcut: HYPRLAND_NO_RT keeps Hyprland off SCHED_RR, so heavy CPU
          # load can make it stutter; drop it once Hyprland ships PR 16737.
          # Under rtkit, Hyprland 0.57's main thread gets a 200 ms
          # RLIMIT_RTTIME, and a slow NVIDIA connector probe on monitor wake or
          # reconnect overruns it inside the kernel, so the kernel SIGKILLs the
          # compositor with no core or log (1 and 2 Nov; Hyprland discussion
          # 16648).
          sessions = pkgs.linkFarm "greeter-sessions" [
            {
              name = "hyprland.desktop";
              path = pkgs.writeText "hyprland.desktop" ''
                [Desktop Entry]
                Name=Hyprland
                Exec=${pkgs.systemd}/bin/systemd-cat -t hyprland ${pkgs.coreutils}/bin/env HYPRLAND_NO_RT=1 ${pkgs.hyprland}/bin/start-hyprland
                Type=Application
                DesktopNames=Hyprland
              '';
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
