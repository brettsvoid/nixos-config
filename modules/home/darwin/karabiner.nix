# Karabiner-Elements config. ~/.config/karabiner/karabiner.json is a symlink to
# an in-store copy of the repo file, so every change goes through
# `darwin-rebuild switch`.
#
# Don't edit in the Karabiner GUI. It saves by renaming a temp file over the
# symlink, so the edit never reaches the repo and the next activation moves it
# aside to karabiner.json.backup. It also reformats the whole file on save, so
# copying its version back makes a noisy diff.
#
# Don't go back to an out-of-store symlink either: Karabiner never re-reads the
# file on its own, and its own saves detach the link. The onChange hook below
# reloads it with `karabiner_cli --select-profile`. home-manager decides
# "changed" by `cmp`-ing the source against the live file (checkFilesChanged in
# its modules/files.nix), so the hook also fires after Karabiner has replaced
# the symlink behind our back.
#
# Only the JSON is managed, so Karabiner's assets/ and automatic_backups/ stay
# as real files.
#
# The app is a `greedy` Homebrew cask (modules/system/darwin/homebrew.nix), so
# the switch is its only update path; greedy is required because brew never
# reports an `auto_updates` cask outdated otherwise. karabiner.json therefore
# sets `global.check_for_updates_on_startup` to false, which takes effect on
# the app's next start.
#
# ─── What is mapped ──────────────────────────────────────────────────
# left ⌘ ↔ left ⌥ on the Moonlander; right_command → Hyper (⌃⌥⇧⌘), with a
# Hyper+A sublayer that opens apps; right_command+hjkl → arrow keys.
#
# The swap is per device, so it follows the Moonlander across the KVM to either
# Mac, but it depends on Karabiner running. The board does not swap ⌘/⌥ in
# firmware: its order is [⌘][⌥][space] against the MacBook's [⌥][⌘][space], so
# the swap puts ⌘ nearest the spacebar on both.
#
# Don't add a second ⌘/⌥ swap via hidutil, System Settings' modifier keys or
# nix-darwin's system.keyboard.swapLeftCommandAndLeftAlt (a bare
# `hidutil property --set` that hits every HID device). Two swaps cancel out:
# that was commit 4e8e5ac's ⌘Q-arriving-as-⌥Q bug.
#
# ─── Universal Control ───────────────────────────────────────────────
# UC works because only the Mac the KVM points at swaps: it forwards
# already-swapped keys, and UC injects above Karabiner's device layer on the
# other Mac, so its per-device mapping never touches them. A system-wide swap
# on either Mac would swap them a second time.
#
# ─── One JSON, two Macs ──────────────────────────────────────────────
# Karabiner has device conditions but no host condition, so every change here
# lands on both machines.
#
# Known broken: the caps_lock → backspace rule is gated on
# `is_built_in_keyboard`, but the built-in keyboard (1452:833) has
# `"ignore": true`, so Karabiner never sees its events. Setting that entry to
# `"ignore": false` fixes it, at the cost of Karabiner grabbing the built-in
# keyboard.
#
# Karabiner applies the FIRST matching manipulator, so any rule added ahead of
# that one for caps_lock shadows it. Nothing here emits F18 any more, although
# AeroSpace (`f18 = "mode hyper"`) and hammerspoon/hyper.lua still bind it.
_: {
  flake.modules.homeManager.darwin-karabiner =
    { config, lib, ... }:
    let
      json = ./karabiner/karabiner.json;
      cli = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli";
      # Read the profile name off the config rather than hardcoding it, so
      # renaming the profile in karabiner.json cannot silently break the reload.
      profiles = (builtins.fromJSON (builtins.readFile json)).profiles;
      profile = (lib.findFirst (p: p.selected or false) (builtins.head profiles) profiles).name;
    in
    {
      xdg.configFile."karabiner/karabiner.json" = {
        source = json;
        onChange = ''
          _link="${config.xdg.configHome}/karabiner/karabiner.json"
          _store="$(readlink "$_link" || true)"
          if [ -x ${lib.escapeShellArg cli} ] && /usr/bin/pgrep -x karabiner_console_user_server >/dev/null; then
            run ${lib.escapeShellArg cli} --select-profile ${lib.escapeShellArg profile}
            # The reload's own save renames a temp file over $_link, replacing
            # the symlink home-manager just made. The save finishes before
            # karabiner_cli exits, so it is safe to put the link back now.
            if [ -n "$_store" ] && [ ! -L "$_link" ]; then
              run ln -sfn "$_store" "$_link"
            fi
          else
            echo "darwin-karabiner: Karabiner is not running; the new config will be read when it next starts"
          fi
        '';
      };
    };
}
