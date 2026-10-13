# vnode-watch: records what fills the kernel's vnode table, as root from
# boot. On the MBP the table has filled for ~30 s a minute or two after a
# login (2, 5 and 9 Oct 2026). Every path lookup and page-in then fails with
# ENFILE ("Too many open files in system"), agents die with SIGBUS, and
# launchd drops some of them (corespotlightd, Control Center, akd). The
# kernel's own record of it is gone within hours, so this keeps one.
#
# Output: /var/log/vnode-watch/<boot time>.log, plus lsof, spindump and
# kernel-log captures per episode, for the newest 10 boots. World-readable,
# so no sudo needed to read it. See vnode-watch/vnode-watch.py.
_: {
  flake.modules.darwin.vnode-watch =
    { pkgs, ... }:
    let
      vnode-watch = pkgs.stdenv.mkDerivation {
        pname = "vnode-watch";
        version = "1.0.0";
        src = ./vnode-watch;

        buildInputs = [ pkgs.python3 ];
        dontConfigure = true;
        dontBuild = true;

        # Stdlib only, so patchShebangs is all the packaging it needs.
        installPhase = ''
          install -Dm755 vnode-watch.py $out/bin/vnode-watch
          patchShebangs $out/bin/vnode-watch
        '';
      };
    in
    {
      launchd.daemons.vnode-watch.serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store && exec ${vnode-watch}/bin/vnode-watch --dir /var/log/vnode-watch"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        # Not Background: launchd throttles those, and the login rush this
        # watches is exactly when it would.
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/vnode-watch.log";
        StandardErrorPath = "/var/log/vnode-watch.log";
      };
    };
}
