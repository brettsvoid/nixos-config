# SonoBus send-path settings for the LAN audio bridge between the two Macs
# (the BlackHole routing diagram lives in modules/hosts/brett-m1-mbp.nix).
#
# ─── Why this exists ─────────────────────────────────────────────────
# Audible gaps on the bridge, diagnosed 2026-09-10. brett-mac-mini is on
# gigabit Ethernet (en0; its Wi-Fi en1 carries nothing, confirmed by
# `netstat -ib` deltas), so brett-m1-mbp's Wi-Fi is the ONLY air hop and it
# owns all of the jitter. 200 pings to the router at 0.1s spacing:
#
#   p50 3.7ms · p90 53ms · p99 89ms · max 90ms · 0% loss
#
# That distribution is bimodal against a hard ~90ms ceiling — 83% of packets
# under 10ms and the rest smeared out to the ceiling — on a pristine radio
# link (-34dBm signal, -86dBm noise, MCS 9, 866 Mbit/s, one co-channel
# neighbour). A hard ceiling is a scheduling artefact; congestion gives a
# smooth tail, and loss would not be zero. So this is not signal strength and
# not bandwidth, and no amount of SonoBus tuning removes it.
#
# SonoBus had already reached the same conclusion by itself: the per-peer
# jitter buffers in PeerStateCacheMap had auto-grown to 138.7ms for the mini
# and 91.7ms for the other peer. That buffer IS the delay, and packets
# arriving past its window ARE the gaps.
#
# These settings shrink what the bridge asks of that air hop. The jitter
# buffer is deliberately left alone: netbufauto is already 2
# (AutoNetBufferModeAutoFull), so SonoBus shrinks it unprompted once the link
# stops needing it — pinning it here would just fight that.
#
# The real fix is a wired MacBook. `networksetup -listnetworkserviceorder`
# already carries a "USB 10/100/1000 LAN" service on en4, ranked above Wi-Fi,
# but the adapter is unplugged (en4 absent from `ifconfig -a`, nothing on
# Thunderbolt). Plugging it in makes everything below unnecessary rather than
# wrong, so none of it is destructive to keep.
#
# ─── Deliberately an activation script ───────────────────────────────
# The same trap apps/obsidian.nix documents, and worse here. SonoBus rewrites
# SonoBus.settings on every option change AND on quit, so pointing a
# read-only store symlink at it would stop the app persisting anything at
# all. sed over the four keys we care about leaves the other ~12KB — device
# names, peer cache, channel groups, recent connections, window geometry —
# under SonoBus's own ownership.
#
# modules/home/darwin/hammerspoon/sonobus-kvm.lua patches this same file the
# same way for the same reason. It only ever writes between a kill and a
# relaunch, which is the one window where the app cannot overwrite it. This
# script cannot assume that window, so it warns instead.
#
# OPERATIONAL NOTE — THE ORDER MATTERS, and getting it wrong looks like a
# no-op rather than an error. A running SonoBus holds these values in memory
# and writes them back over the file on its next option change or on quit, so
# patching underneath it achieves nothing: the quit overwrites the patch and
# the relaunch reads the old values. Confirmed 2026-09-10 by doing exactly
# that — the switch ran, SonoBus was quit and relaunched, and all three keys
# were back at 4.0 / 0.0 / 2.0 with the file mtime matching the relaunch.
#
# The order that works is:
#
#   1. quit SonoBus
#   2. nix-rebuild
#   3. start SonoBus
#
# So activation refuses to patch while SonoBus is running and says this
# instead. sonobus-kvm.lua gets away with patching because it only ever
# writes between a SIGKILL and a relaunch, and SIGKILL writes nothing back.
#
# ─── The *.sonobus setup files matter just as much ───────────────────
# On brett-mac-mini, sonobus-kvm.lua relaunches with
# `--load-setup kvm-headset.sonobus` every time the KVM hands the headset
# back, and hammerspoon.nix already documents the trap: --load-setup is
# applied AFTER SonoBus.settings, so whatever the snapshot carries wins. It
# was checked, and kvm-headset.sonobus does carry all three PARAMs (at the
# old 4.0 / 0.0 / 2.0), which means patching SonoBus.settings alone would be
# silently reverted on the next KVM switch.
#
# So every *.sonobus in the directory is patched too. The glob matches nothing
# on the MacBook, which has no setup file and does not use --load-setup. The
# snapshots hold no PeerStateCacheMap, so the sendformat expression simply
# finds nothing there — harmless.
#
# This does not put the setup file under nix's ownership, and hammerspoon.nix's
# reasoning for leaving it out of the repo still stands: it is a SonoBus
# snapshot of live device and mixer state, regenerated with Save Setup..., and
# it embeds machine-local device names.
#
# ─── Values, read from the SonoBus source rather than inferred ───────
# github.com/sonosaurus/sonobus, Source/SonobusPluginProcessor.{h,cpp}.
# Note the file mixes scales: `defnetbuf` is in SECONDS (its display lambda
# does v*1000.0, so 0.13 means 130ms) while per-peer `netbuf` is already in
# ms. Nothing below touches either, but it is the trap to know about.
#
#   dynamicresampling  AudioParameterBool, was OFF. Maps to aoo's
#                      set_dynamic_resampling on both the sink and the source
#                      of every peer, i.e. clock-drift correction. The two
#                      ends genuinely are independent clock domains: a real
#                      crystal in the headset on the mini, the host clock
#                      behind BlackHole on the MacBook. Nothing was
#                      correcting that drift. Worth knowing for diagnosis —
#                      drift gaps arrive on a regular period, jitter gaps are
#                      irregular and bursty.
#
#   sendchannels       AudioParameterChoice over
#                      { "Match # Inputs", "Send Mono", "Send Stereo" },
#                      stored as the index, so 1 is Send Mono. Was 2, which
#                      doubled the Opus payload for what is call audio. The
#                      handler applies it to every peer at once via
#                      setRemotePeerNominalSendChannelCount(-1, ...), so
#                      there is no per-peer override to chase.
#
#   defsendqual        AudioParameterInt indexing the format table, which
#                      sets bitrate AND packet size through
#                      min_preferred_blocksize:
#
#                        0 = 16k/960   1 = 24k/480   2 = 48k/240
#                        3 = 64k/240   4 = 96k/120   5 = 128k/120 …
#                        then PCM 16/24/32-bit at 8-10
#
#                      The block actually sent is
#                      max(audioDeviceBufferSize, min_preferred_blocksize).
#                      On the MacBook's 128-sample buffer index 1 gives 480
#                      samples = 10ms = 100 packets/s, against index 3's 240
#                      samples = 5ms = 200 packets/s. Wi-Fi airtime cares far
#                      more about packet RATE than about bandwidth, so the
#                      index matters twice over. (The mini's buffer is 512,
#                      above the 480 minimum, so it lands at 10.7ms.)
#
#   sendformat         The SAME index, cached per peer in PeerStateCacheMap —
#                      and this is the one that actually bites.
#                      findOrAddRemotePeer assigns
#                      `retpeer->formatIndex = cache.sendFormat`
#                      unconditionally on connect, so patching defsendqual
#                      alone would change nothing for a peer already cached.
#                      ExtraState ChangeQualForAll is 0, so a runtime change
#                      to the default would not propagate either. Every
#                      cached peer is therefore rewritten to match. The
#                      attribute name appears nowhere else in the file
#                      (`peerSendFormatKey`), so the global sed is safe.
#
# Measured on the wire before the change: 200 packets/s at 175 kbit/s out,
# which is 64 kbit/s x 2 channels plus 200 x 28 bytes of UDP/IP overhead
# almost exactly — so the model behind the table above is sound. Index 1 in
# mono predicts roughly 46 kbit/s at 100 packets/s.
_: {
  flake.modules.homeManager.darwin-sonobus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sed = "${pkgs.gnused}/bin/sed";
      cmp = "${pkgs.diffutils}/bin/cmp";

      support = "${config.home.homeDirectory}/Library/Application Support/SonoBus";

      # Opus 24 kbps/ch on a 480-sample minimum block. Both halves of that
      # are the point; see the format table above.
      sendQuality = 1;

      # Stored as floats even where the parameter is a bool or an index.
      dynamicResampling = "1.0"; # on
      sendChannels = "1.0"; # "Send Mono"
    in
    {
      home.activation.sonobusSendPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Patching underneath a running SonoBus is worse than not patching:
        # a clean quit writes its in-memory settings back over the file, so
        # the patch is silently lost and the next launch reads the OLD
        # values. Measured 2026-09-10 — the switch ran, SonoBus was quit and
        # relaunched, and all three keys came back at their old values with
        # the file mtime matching the relaunch. Refuse instead, and say the
        # order that works.
        # No `exit` here: home-manager concatenates every activation entry
        # into one script, so an early exit would skip everything after this.
        if /usr/bin/pgrep -x SonoBus > /dev/null 2>&1; then
          warnEcho "SonoBus is running, so its settings were NOT patched: a clean quit would overwrite them. Quit SonoBus, re-run the switch, then start it again."
        else
          for TARGET in "${support}/SonoBus.settings" "${support}"/*.sonobus; do
            # SonoBus.settings is absent until the app has run once here, and
            # an unmatched glob stays literal. Neither is an error.
            [ -f "$TARGET" ] || continue

            NEW="$TARGET.hm-new"

            ${sed} \
              -e 's|<PARAM id="dynamicresampling" value="[^"]*"/>|<PARAM id="dynamicresampling" value="${dynamicResampling}"/>|' \
              -e 's|<PARAM id="sendchannels" value="[^"]*"/>|<PARAM id="sendchannels" value="${sendChannels}"/>|' \
              -e 's|<PARAM id="defsendqual" value="[^"]*"/>|<PARAM id="defsendqual" value="${toString sendQuality}.0"/>|' \
              -e 's|sendformat="[0-9]*"|sendformat="${toString sendQuality}"|g' \
              "$TARGET" > "$NEW"

            # Only write on a real difference. SonoBus owns these files and
            # rewrites them constantly, so an unconditional rewrite on every
            # switch would race that for nothing.
            if ${cmp} -s "$TARGET" "$NEW"; then
              rm -f "$NEW"
            else
              run mv "$NEW" "$TARGET"
              # `run` is a no-op under --dry-run, leaving $NEW behind.
              rm -f "$NEW"
            fi
          done
        fi
      '';
    };
}
