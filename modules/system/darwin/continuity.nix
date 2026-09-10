# Turns off AirDrop and Handoff. Imported by brett-m1-mbp only.
#
# ─── Why, and what is actually proven ────────────────────────────────
# This is a Wi-Fi latency measure for the SonoBus audio bridge, not a privacy
# or tidiness one. modules/home/darwin/sonobus.nix carries the full
# diagnosis; the short version is that the MacBook's air hop shows a bimodal
# delay against a hard ~90ms ceiling at 0% loss on an otherwise pristine
# radio link, and a hard ceiling like that is a scheduling artefact rather
# than congestion or weak signal.
#
# AWDL is the leading suspect. It is Apple's peer-to-peer Wi-Fi link behind
# AirDrop and Continuity, and it time-shares the one radio by hopping it to a
# social channel on a schedule — while the radio is off-channel the station
# can neither send nor receive on the home channel, which is exactly the
# shape observed. `awdl0` is UP and active on this machine.
#
# BUT THAT CAUSE IS NOT PROVEN, and this module must not be read as a fix.
# Proving it needs `sudo ifconfig awdl0 down` and a re-run of the ping
# histogram, which could not be done at diagnosis time (sudo needs a
# password, `log show --predicate 'subsystem == "com.apple.wifi"'` returns
# nothing useful, macOS ifconfig exposes no power-save flag, and the
# `airport` utility is gone from current macOS). Treat this as a cheap,
# reversible experiment with a measurement attached:
#
#   ping -c 200 -i 0.1 "$(route -n get default | awk '/gateway/{print $2}')"
#
# Before: p50 3.7ms, p90 53ms, p99 89ms, max 90ms. If the tail does not
# collapse, revert this module rather than keeping it on faith.
#
# ─── What this does not cover ────────────────────────────────────────
# AirDrop and Handoff are only two of the things that raise AWDL. Sidecar,
# Universal Control, AirPlay receiving and Continuity Camera all drive it
# too, so `awdl0` may well stay up after this.
#
# Universal Control is NOT a free lever to pull next: it is in active use
# between the two Macs, and modules/home/darwin/karabiner.nix depends on that
# — the ⌘/⌥ swap is applied on the mini only precisely so UC can forward
# already-swapped keys. Disabling it to chase Wi-Fi latency would break a
# working setup, so measure before reaching for it.
#
# ─── What it costs ───────────────────────────────────────────────────
# Handoff between this Mac and the iPhone/iPad, and Universal Clipboard with
# it — System Settings groups the two under one switch, and the same daemon
# owns both. AirDrop to and from this Mac stops working entirely; sending
# files to the mini over the LAN still works.
#
# ─── Keys, validated against the binaries that read them ─────────────
# Neither has a nix-darwin option (`system.defaults.controlcenter.AirDrop`
# only controls the menu-bar icon), so both go through CustomUserPreferences,
# which nix-darwin writes as `system.primaryUser` via `launchctl asuser`.
#
#   DisableAirDrop               found in /usr/libexec/sharingd, the daemon
#                                that implements AirDrop, alongside the
#                                NetworkBrowser domain name itself.
#
#   ActivityAdvertisingAllowed   found in UserActivity.framework's
#   ActivityReceivingAllowed     Agents/useractivityd, together with log
#                                strings that pin the semantics down:
#                                "Failing request because
#                                self.activityAdvertisingAllowed == NO".
#
# Both are cached in the daemon at startup, so a `defaults write` alone does
# not take effect. After the first switch that applies this, either log out
# and back in or kick the two agents:
#
#   launchctl kickstart -k gui/$UID/com.apple.coreservices.useractivityd
#   launchctl kickstart -k gui/$UID/com.apple.sharingd
#
# Not done from activation on purpose. nix-darwin's system activation runs as
# root, so reaching into the user's GUI launchd domain means hard-coding a
# UID, and restarting sharingd mid-transfer is a worse failure than a
# one-time manual step.
_: {
  flake.modules.darwin.continuity = {
    system.defaults.CustomUserPreferences = {
      "com.apple.NetworkBrowser".DisableAirDrop = true;

      "com.apple.coreservices.useractivityd" = {
        ActivityAdvertisingAllowed = false;
        ActivityReceivingAllowed = false;
      };
    };
  };
}
