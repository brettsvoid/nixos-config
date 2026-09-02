# Karabiner-Elements config. The repo file is the single source of truth: it is
# copied into the nix store and ~/.config/karabiner/karabiner.json is a symlink
# to that copy, so every change goes through `darwin-rebuild switch`.
#
# DO NOT edit in the Karabiner GUI. Measured: Karabiner saves by writing a temp
# file and renaming it over ~/.config/karabiner/karabiner.json, which replaces
# the symlink with a plain file. The write never reaches the repo (sha256 and
# mtime unchanged across two saves), and the next activation moves that plain
# file aside to karabiner.json.backup and re-links — so a GUI edit applies only
# until the next switch, then vanishes with no warning. Karabiner also reformats
# on save (reorders keys, collapses single-element arrays onto one line, drops
# the trailing newline), so copying its version back is a noisy diff.
#
# This was an out-of-store symlink to the repo file until 2026-09-01, on the
# theory that repo edits went live without a rebuild. They did not, twice over:
#
#   - Karabiner never re-reads the file on its own. The daemon log shows no
#     "Load .../karabiner.json" for hours after a write; only an explicit
#     `karabiner_cli --select-profile` forces it.
#   - That reload's own save detaches the symlink (above), so the NEXT repo edit
#     would be read from a stale detached copy — silently, and only after the
#     first edit of a session appeared to work.
#
# An in-store copy plus the onChange hook below closes both. home-manager
# decides "changed" by `cmp`-ing the source against the live file rather than
# comparing store paths (modules/files.nix, checkFilesChanged), so the hook also
# fires when Karabiner has detached and rewritten the file behind our back. It
# reloads, then puts back the symlink that the reload's save just destroyed —
# measured as safe, because the save completes before karabiner_cli exits and
# nothing re-clobbers the link afterwards.
#
# Trade-off accepted: a keymap tweak now needs a rebuild. It always did — the
# no-rebuild path never survived past its first use.
#
# Only the JSON is managed, not the whole karabiner dir, so Karabiner's own
# assets/ and automatic_backups/ stay as real files in ~/.config.
#
# Karabiner-Elements itself is installed as a Homebrew cask (see
# modules/system/darwin/homebrew.nix), where it is marked `greedy = true` so
# every switch upgrades it. That flag is required: the cask is flagged
# auto_updates, which brew reads as "never outdated" unless asked greedily.
#
# The switch is therefore the ONLY update path, so karabiner/karabiner.json
# sets `global.check_for_updates_on_startup` to false — otherwise the app's own
# updater nags on every launch and can install a version brew doesn't know
# about. It is read at app startup, so it takes effect on the next restart.
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
_: {
  flake.modules.homeManager.darwin-karabiner =
    { config, lib, ... }:
    let
      json = ./karabiner/karabiner.json;
      cli = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli";
      # Read the profile name off the config rather than hardcoding it, so
      # renaming the profile in the GUI cannot silently break the reload.
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
            # the symlink home-manager just made. Put it back.
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
