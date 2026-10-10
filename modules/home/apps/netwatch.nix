# netwatch: an always-on record of where the network dropped, by layer. A
# brief drop could be the radio, the router, its power, the LAN resolvers or
# the ISP, it is over before anyone looks, and macOS keeps no usable history
# of it. So this probes three points continuously and records every outage:
#
#   air   ICMP to the default gateway    -> the local hop + the router
#   dns   DNS query to the LAN resolver  -> the LAN path + your own resolver
#   wan   ICMP to a public address       -> everything beyond the router
#
# Run it on both Macs: brett-mac-mini is wired and brett-m1-mbp is not, so a
# drop both see is the router or its power, and one only the MacBook sees is
# the air hop.
#
# The agent's 4 Hz suits multi-second outages, not latency: below ~10 Hz a
# periodic stall aliases into a false slow cycle. `netwatch --burst 30`
# (50 Hz) is for that; see burst() in netwatch/netwatch.py.
_: {
  flake.modules.homeManager.apps-netwatch =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.local.netwatch;

      netwatch = pkgs.stdenv.mkDerivation {
        pname = "netwatch";
        version = "1.0.0";
        src = ./netwatch;

        buildInputs = [ pkgs.python3 ];
        dontConfigure = true;
        dontBuild = true;

        # Stdlib only, so patchShebangs is all the packaging it needs.
        installPhase = ''
          install -Dm755 netwatch.py $out/bin/netwatch
          patchShebangs $out/bin/netwatch
        '';
      };

      dataDir = "${config.home.homeDirectory}/.local/share/netwatch";
    in
    {
      options.local.netwatch = {
        interval = lib.mkOption {
          type = lib.types.float;
          default = 0.25;
          description = ''
            Seconds between probes for the always-on agent. 0.25 catches
            multi-second outages at a negligible cost. Do NOT lower this to
            chase latency — use `netwatch --burst` instead, which is built for
            it; a permanently high probe rate mostly just keeps a laptop's
            radio awake.
          '';
        };

        wan = lib.mkOption {
          type = lib.types.str;
          default = "1.1.1.1"; # gitleaks:allow - public resolver, not a secret
          description = ''
            Address probed to represent "beyond the router". Must answer ICMP
            echo and should not be the LAN resolvers, or a resolver outage and
            an ISP outage become indistinguishable.
          '';
        };

        retainDays = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = ''
            Days of per-second samples to keep. One file per day, roughly
            15 MB each at the default interval; events.csv is never pruned
            because it is tiny and it is the actual record.
          '';
        };
      };

      config = lib.mkIf pkgs.stdenv.isDarwin {
        home.packages = [ netwatch ];

        # `--quiet` drops the live status line, which is redrawn with \r and
        # would grow the log without bound; outage lines are still logged.
        #
        # ProcessType Interactive, not Background: launchd throttles
        # Background jobs, and this one times round trips.
        #
        # No PATH needed: route, ifconfig, ipconfig and scutil live in /sbin
        # or /usr/sbin, on launchd's default PATH, and terminal-notifier is
        # called by absolute path.
        launchd.agents.netwatch = {
          enable = true;
          config = {
            ProgramArguments = [
              "${netwatch}/bin/netwatch"
              "--quiet"
              "--outdir"
              dataDir
              "--interval"
              (toString cfg.interval)
              "--wan"
              cfg.wan
              "--retain-days"
              (toString cfg.retainDays)
            ];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Interactive";
            StandardOutPath = "/tmp/netwatch.log";
            StandardErrorPath = "/tmp/netwatch.log";
          };
        };
      };
    };
}
