# SonoBus send-path settings for the LAN audio bridge between the two Macs
# (the BlackHole routing diagram is in modules/hosts/brett-m1-mbp.nix):
# dynamic resampling on, plus per-host send channels and send format.
#
# Audible gaps on the bridge are jitter on brett-m1-mbp's Wi-Fi, the only
# wireless hop (the mini is wired), and no SonoBus setting removes them: a
# lower send format and mono were tried and made no difference. The jitter
# buffer is left to SonoBus's auto-full mode (netbufauto 2), which shrinks it
# once the link allows; pinning it would fight that. The real fix is a wired
# MacBook: its "USB 10/100/1000 LAN" service is already ranked above Wi-Fi,
# so it only needs the adapter plugged in.
#
# To test AWDL as the cause, run `sudo ifconfig awdl0 down` and re-measure
# with `netwatch --burst 30` (modules/home/apps/netwatch.nix). Don't turn
# AirDrop/Handoff off via `system.defaults` instead: sharingd and
# useractivityd read those keys only at startup and SIP blocks
# `launchctl kickstart`, so nothing applies until logout, even though
# `defaults read` already shows the new value. That attempt was reverted:
# `git log --diff-filter=D -- modules/system/darwin/continuity.nix`.
#
# ─── Why it is an activation script ──────────────────────────────────
# SonoBus rewrites SonoBus.settings on every option change and on quit, so a
# read-only store symlink would stop it saving anything (the same trap as
# modules/home/apps/obsidian.nix). sed rewrites only the keys below.
#
# Quit SonoBus before switching: a running SonoBus writes its in-memory
# settings back over the file on quit, silently undoing the patch, so
# activation skips the patch and warns instead. hammerspoon/sonobus-kvm.lua
# patches the same file safely because it writes only between a SIGKILL and
# the relaunch.
#
# Every *.sonobus setup file is patched too. On the mini, sonobus-kvm.lua
# relaunches with `--load-setup kvm-headset.sonobus`, which is applied after
# SonoBus.settings (see hammerspoon.nix) and carries these PARAMs as well, so
# patching SonoBus.settings alone would be undone on the next KVM switch.
#
# ─── Values ──────────────────────────────────────────────────────────
# From SonoBus's Source/SonobusPluginProcessor.{h,cpp}:
#
#   dynamicresampling  Clock-drift correction. The ends are separate clock
#                      domains (the headset on the mini, the host clock behind
#                      BlackHole on the MacBook). Drift gaps are periodic;
#                      jitter gaps are irregular.
#   sendchannels       Choice index (channelIndex below); per host, see the
#                      note on the option.
#   defsendqual        Index into the send format table, which sets bitrate
#                      and minimum block size:
#                        0 = 16k/960   1 = 24k/480   2 = 48k/240
#                        3 = 64k/240   4 = 96k/120   5 = 128k/120 …
#                        then PCM 16/24/32-bit at 8-10
#                      The block sent is max(device buffer, that minimum), so
#                      on the MacBook's 128-sample buffer index 3 sends 200
#                      packets/s and index 1 halves that.
#   sendformat         The same index, cached per peer in PeerStateCacheMap
#                      and applied on connect in place of defsendqual, so
#                      every cached peer is rewritten too. Nothing else in the
#                      file uses that attribute, so the global sed is safe.
#
# If you ever pin the jitter buffer: defnetbuf is in seconds, but per-peer
# netbuf is in ms.
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

      cfg = config.local.sonobus;

      # The stored value is the choice index.
      channelIndex = {
        match = 0;
        mono = 1;
        stereo = 2;
      };

      # Stored as a float even though the parameter is a bool.
      dynamicResampling = "1.0"; # on
      sendChannels = "${toString channelIndex.${cfg.sendChannels}}.0";
      sendQuality = cfg.sendQuality;
    in
    {
      # ─── Per host, because "send" means opposite things on the two ────
      # `sendchannels` is what THIS machine puts on the wire:
      #
      #   brett-m1-mbp    BlackHole 16ch, the call/music audio bound for the
      #                   headset. Mono here would make the music mono.
      #   brett-mac-mini  the PRO X headset's microphone, which captures mono,
      #                   so stereo just duplicates a channel.
      options.local.sonobus = {
        sendChannels = lib.mkOption {
          type = lib.types.enum [
            "match"
            "mono"
            "stereo"
          ];
          default = "stereo";
          description = ''
            What this machine sends: "mono" for a microphone source,
            "stereo" for programme audio, "match" to follow the input
            channel count. Defaults to stereo -- the choice that cannot
            quietly throw away a channel.
          '';
        };

        sendQuality = lib.mkOption {
          type = lib.types.ints.between 0 14;
          default = 3;
          description = ''
            Index into SonoBus's send format table (see the header). Sets
            bitrate AND packet size, so it is the Wi-Fi lever as well as the
            quality one. 3 is Opus 64 kbps/ch on 240-sample blocks.
          '';
        };
      };
      # `options` is present, so the rest has to sit under `config`.
      config.home.activation.sonobusSendPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
