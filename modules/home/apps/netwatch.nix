# netwatch — a always-on record of WHERE the network dropped, by layer.
#
# ─── Why this exists ───────────────────────────────────────────────────
# "The Wi-Fi drops for a second or two" is unfalsifiable on its own: a brief
# outage on brett-m1-mbp could be the radio, the router, the mains feeding the
# router, the LAN resolvers on .50/.51, or the ISP — and by the time you look,
# it is over and nothing has recorded it. macOS keeps no usable history either:
# `log show` holds a few days, and airportd's `WiFiNetworkDisconnectReason` /
# `LastDriverUnavailableReason` are LAST-VALUE fields repeated in a periodic
# state dump, so counting their occurrences invents hundreds of events that
# never happened.
#
# So this probes three points continuously and writes down every outage:
#
#   air   ICMP to the default gateway    -> the local hop + the router
#   dns   DNS query to the LAN resolver  -> the LAN path + your own resolver
#   wan   ICMP to a public address       -> everything beyond the router
#
# Running it on BOTH Macs is the point. brett-mac-mini is wired and
# brett-m1-mbp is not, so a drop the mini also sees is the router or the power
# feeding it, and a drop only the MacBook sees is the air hop. That comparison
# is what separates "the dehumidifier browned out the router" from "the radio
# stalled", and no amount of measuring from one machine can do it.
#
# ─── Two sampling rates, on purpose ────────────────────────────────────
# The agent samples at 4 Hz, which is right for catching multi-second outages
# and cheap enough to leave running forever. It is the WRONG rate for
# measuring latency: sample slower than ~100 ms and a periodic stall aliases
# into a fictitious slow cycle — the ~0.46 s AWDL stall period on this machine
# reads as a ~10 s one at 0.25 s spacing, which is a very convincing wrong
# answer. `netwatch --burst 30` exists for that: 50 Hz, decoupled send and
# receive, and it names AWDL when it finds a tightly periodic stall.
#
# Cross-checked against /sbin/ping run concurrently at both rates; the two
# agree, which is the only reason to trust either.
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

        # Stdlib only — no third-party deps, so a plain interpreter and
        # patchShebangs is the whole packaging story.
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
        # would otherwise grow the log without bound. Outage lines are still
        # printed, so the log stays a readable chronology of drops.
        #
        # ProcessType is "Interactive" rather than the usual "Background"
        # deliberately: Background asks launchd to throttle a job, and this job
        # spends nearly all its time asleep between probes, which is exactly
        # the profile that gets throttled hardest. Since the whole purpose is
        # to time round trips, the scheduler should not be adding to them.
        #
        # No EnvironmentVariables.PATH needed: every external tool the script
        # shells out to (route, ifconfig, ipconfig, networksetup, scutil) lives
        # in /sbin or /usr/sbin, which are already in launchd's default PATH.
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
