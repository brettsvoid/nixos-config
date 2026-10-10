# Hammerspoon config. ~/.hammerspoon/*.lua are symlinks to in-store copies of
# these files, so every change goes through `darwin-rebuild switch`.
#
# Unlike darwin-karabiner, this needs no onChange reload hook: the
# ReloadConfiguration spoon's path watcher on ~/.hammerspoon fires when
# home-manager creates, repoints or removes a symlink, and Hammerspoon never
# rewrites its own config.
#
# Only the .lua files are managed, so Spoons/ (EmmyLua, ReloadConfiguration)
# stays as real files that Hammerspoon's own Spoon manager can update.
#
# init.lua requires `hs.ipc` so the `hs` CLI can query the running config
# (`hs -c '...'`). /opt/homebrew/bin/hs is a hand-made symlink to
# Hammerspoon.app/Contents/Frameworks/hs/hs, not managed here.
#
# The Hammerspoon cask is in the shared list (modules/system/darwin/
# homebrew.nix), but only brett-mac-mini imports this module, because
# sonobus-kvm.lua is specific to its KVM and headset. The MacBook keeps its
# own unmanaged ~/.hammerspoon.
#
# ─── Traps ───────────────────────────────────────────────────────────
# Don't write files into ~/.hammerspoon from a module: the ReloadConfiguration
# watcher reloads on every write, so a module that logs there reloads in a
# loop.
#
# Lua errors go to the Hammerspoon console, not the unified log, so a module
# that fails at load is easy to miss.
# `hs -c 'hs.audiodevice.watcher.isRunning()'` confirms sonobus-kvm.lua started.
#
# ─── Setup file is not managed here ──────────────────────────────────
# sonobus-kvm.lua relaunches SonoBus with `--load-setup` pointed at
# ~/Library/Application Support/SonoBus/kvm-headset.sonobus, a snapshot of a
# working device and mixer state made with Save Setup... in SonoBus. It embeds
# machine-local device names, so it stays out of the repo. Without it the
# restart relies on the SonoBus.settings patch alone, so a fresh machine
# degrades rather than breaks.
#
# Save it with auto-reconnect on (reconnectlast="1.0"): --load-setup is applied
# after SonoBus.settings, so its values win and a setup saved with reconnect
# off brings every restart up disconnected.
{
  flake.modules.homeManager.darwin-hammerspoon = {
    home.file = {
      ".hammerspoon/init.lua".source = ./hammerspoon/init.lua;
      ".hammerspoon/hyper.lua".source = ./hammerspoon/hyper.lua;
      ".hammerspoon/sonobus-kvm.lua".source = ./hammerspoon/sonobus-kvm.lua;
    };
  };
}
