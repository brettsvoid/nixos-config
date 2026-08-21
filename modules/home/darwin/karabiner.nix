# Karabiner-Elements config. Symlinks ~/.config/karabiner/karabiner.json →
# repo (out-of-store), so the repo file is the live one Karabiner reads and
# writes.
#
# Edits do NOT take effect on save. Karabiner's file watcher never fires
# across the nix symlink chain (~/.config → home-manager-files → a store
# symlink → the repo file); the daemon log shows no "Load .../karabiner.json"
# for hours after a write. Force it:
#
#   "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" \
#     --select-profile "Default profile"
#
# and confirm in /var/log/karabiner/core_service.log. Still no rebuild
# required — but "save and it reloads" is not true here.
#
# Only the JSON is symlinked, not the whole karabiner dir, so Karabiner's
# own `assets/` and `automatic_backups/` stay as real files in ~/.config.
#
# Karabiner-Elements itself is installed as a Homebrew cask (see
# modules/system/darwin/homebrew.nix).
#
# ─── What is actually mapped ─────────────────────────────────────────
# left ⌘ ↔ left ⌥ ON THE MOONLANDER, and right_command → Hyper (⌃⌥⇧⌘) with
# vim-style sublayers.
#
# The Moonlander swap lives here, per-device, and it replaced the mac mini's
# system-wide `system.keyboard.swapLeftCommandAndLeftAlt` (modules/system/
# darwin/keyboard.nix, deleted). Reasons, all measured:
#
#   - The Moonlander is stock in this respect. It does NOT remap ⌘/⌥ in
#     firmware, contrary to what keyboard.nix claimed. Its physical order is
#     [⌘][⌥][space]; the MacBook's is [⌥][⌘][space]. The swap is what makes
#     the key nearest the spacebar ⌘ on both.
#   - nix-darwin's option shells out to a bare `hidutil property --set` with
#     no `--matching`, so it stamped every HID device on the machine —
#     measured: built-in keyboard, Karabiner's virtual keyboard, the
#     Moonlander, TouchBarUserDevice and two headsets.
#   - It only ever WORKED because Karabiner grabs the Moonlander and re-emits
#     through its virtual keyboard, which the global mapping then caught. A
#     hidutil mapping scoped to the Moonlander's own IDs would never fire.
#   - Doing it here keeps the swap with the keyboard, so it follows the
#     Moonlander across the KVM to either Mac. Before, the mini swapped and
#     the MacBook did not, so the same keyboard behaved differently depending
#     on which machine the KVM pointed at.
#
# Trade-off accepted: the swap now depends on Karabiner running, where
# hidutil applied at boot independently of it.
#
# DO NOT also swap ⌘/⌥ at the hidutil layer. The two stack — they are
# separate properties (`UserKeyMapping` vs the System Settings
# `HIDKeyboardModifierMappingPairs`, both live on the device at once) — and
# stacked they cancel out. That is commit 4e8e5ac's ⌘Q-arriving-as-⌥Q bug.
#
# ─── Universal Control ───────────────────────────────────────────────
# UC keeps working precisely BECAUSE only one machine swaps. The mini
# applies the swap and forwards already-swapped keys; the MacBook adds
# nothing on top. A system-wide swap on the MacBook would swap them a second
# time and break it. UC never appears as a HID device in Karabiner's logs, so
# it injects above that layer and per-device mappings cannot reach it.
#
# ─── One JSON, two Macs ──────────────────────────────────────────────
# There is no host condition to work with — only device conditions. That is
# fine for the Moonlander (same keyboard, same treatment on both), but note
# it means a change here lands on BOTH machines on the next pull.
#
# KNOWN BROKEN: the caps_lock → backspace rule is gated on
# `is_built_in_keyboard`, but the built-in keyboard (1452-833) carries
# `"ignore": true` in the devices list, so Karabiner never sees its events
# and the rule cannot fire. Confirmed by hand: caps_lock does not backspace.
# The grab log lists exactly one device — the Moonlander. Fixing it means
# flipping that device entry to `"ignore": false`.
#
# There used to be a rule ahead of that one mapping caps_lock → F18 on the
# built-in keyboard, to trigger the old skhd stack's `hyper_mode`. It was
# removed along with skhd itself: AeroSpace binds nothing to F18, and because
# Karabiner takes the FIRST matching manipulator, that rule also shadowed the
# backspace mapping on the MacBook's built-in keyboard — external keyboards
# got backspace, the built-in one got a dead key.
{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.darwin-karabiner =
    { config, ... }:
    {
      xdg.configFile."karabiner/karabiner.json".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/darwin/karabiner/karabiner.json";
    };
}
