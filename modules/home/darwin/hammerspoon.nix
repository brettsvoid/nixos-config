# Hammerspoon config. The repo files are the single source of truth: they are
# copied into the nix store and ~/.hammerspoon/*.lua are symlinks to those
# copies, so every change goes through `darwin-rebuild switch`.
#
# Unlike darwin-karabiner, this needs NO onChange reload hook. The
# ReloadConfiguration spoon runs an hs.pathwatcher on ~/.hammerspoon, and
# measured 2026-09-03 it fires on exactly the operations home-manager performs:
# creating a symlink, repointing one at a new store path, and removing one each
# produced one reload. Hammerspoon also never rewrites its own config, so the
# detach-on-save problem that forced karabiner in-store does not arise here.
#
# Only the .lua files are managed, not the whole directory, so Spoons/ (EmmyLua,
# ReloadConfiguration) stays as real files that Hammerspoon's own Spoon manager
# can install and update.
#
# `hs.ipc` is required from init.lua so the `hs` CLI can talk to the running
# config — that is what makes this debuggable from a terminal (`hs -c '...'`).
# Note the CLI at /opt/homebrew/bin/hs is a hand-made symlink into the app
# bundle, not a brew formula and not managed here; the real binary ships with
# the cask at Hammerspoon.app/Contents/Frameworks/hs/hs.
#
# Hammerspoon itself is a Homebrew cask in the SHARED list (modules/system/
# darwin/homebrew.nix), so it is installed on both Macs. This module is
# imported only by brett-mac-mini, because the one thing it does beyond the
# hyper key is mac-mini hardware specific — see below. The MacBook keeps its
# own unmanaged ~/.hammerspoon.
#
# ─── sonobus-kvm.lua: what it works around ───────────────────────────
# The KVM switches the PRO X Wireless dongle between four machines, including a
# Windows box, so the headset genuinely has to leave the mini. Diagnosed
# 2026-09-03 by logging CoreAudio state across a switch:
#
#   - When the headset leaves, SonoBus falls back to "Mac mini Speakers", an
#     output-only device (in=0). Its <InputChannelGroups numChanGroups="1">
#     group has nothing to bind to and collapses.
#   - When the headset returns it has the SAME CoreAudio UID
#     (...:PRO X Wireless Gaming Headset:2123000:1,2), full channels, and is
#     already the system default input AND output — yet SonoBus stays parked on
#     the speakers.
#   - Re-picking the device restores the device but not the channel group, which
#     is why recovering by hand took two passes through the dropdown.
#
# Confirmed via the macOS 14+ process objects API that after one manual toggle
# SonoBus reports IsRunningInput=1 — the input stream is open and running —
# while no microphone audio transmits. Device binding healthy, send path dead.
# So it is a SonoBus bug, not configuration, and SonoBus exposes no option to
# prevent the fallback: its entire audio device option set is sample-rate
# override, drift correction, Bluetooth input and the FX limiter.
#
# Nothing short of a restart rebuilds that channel group, so the module restarts
# SonoBus on the headset reappearing, relaunching with `--load-setup`. That
# setup file carries "any device selection, input mixer setup, and all other
# options" — the input mixer being exactly the state that collapses.
#
# ─── Two traps, both hit and measured ────────────────────────────────
# 1. DO NOT write logs into ~/.hammerspoon. The ReloadConfiguration path
#    watcher sees the write and reloads, which re-runs the module, which logs
#    again: ~50 reloads in 3 seconds. The log goes to ~/Library/Logs instead.
# 2. hs.audiodevice has NO channel-count method. An earlier version called
#    d:inputChannels(), which is nil, so headsetReady() threw at load, M.start()
#    never ran and the watcher never started — silently, because Hammerspoon
#    reports Lua errors to its own console and not to the unified log. Use
#    :isInputDevice(). `hs -c 'hs.audiodevice.watcher.isRunning()'` is the check
#    that catches this class of failure.
#
# ─── Setup file is NOT managed here ──────────────────────────────────
# ~/Library/Application Support/SonoBus/kvm-headset.sonobus is deliberately left
# out of the repo. It is a SonoBus-generated snapshot of a working device and
# mixer state, regenerated with Save Setup... when that state legitimately
# changes, and it embeds machine-local device names. The module falls back to
# patching SonoBus.settings directly when the file is absent, so a fresh machine
# degrades rather than breaks.
#
# Note it must carry reconnectlast="1.0": --load-setup is applied AFTER
# SonoBus.settings, so a setup file saved with auto-reconnect off silently
# overrides the module's own pinning and every restart comes up disconnected.
{
  flake.modules.homeManager.darwin-hammerspoon = {
    home.file = {
      ".hammerspoon/init.lua".source = ./hammerspoon/init.lua;
      ".hammerspoon/hyper.lua".source = ./hammerspoon/hyper.lua;
      ".hammerspoon/sonobus-kvm.lua".source = ./hammerspoon/sonobus-kvm.lua;
    };
  };
}
