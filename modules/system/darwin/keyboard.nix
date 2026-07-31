# Modifier-key remapping, via hidutil.
#
# Swaps left ⌘ and left ⌥ across every attached keyboard. This is here for
# Universal Control: sharing one keyboard between machines means living with
# whichever modifier layout the other end expects, and the swap is what makes
# that bearable rather than a constant misfire.
#
# This REPLACES a hand-rolled ~/Library/LaunchAgents/com.local.KeyRemapping.plist
# that ran the same `hidutil property --set` at every login. nix-darwin's
# `swapLeftCommandAndLeftAlt` emits a byte-identical UserKeyMapping pair
# (left ⌘ 0x7000000E3 ↔ left ⌥ 0x7000000E2), so this is a like-for-like
# migration, not a behaviour change. Delete that plist — leaving it in place
# is not merely redundant, it re-applies the swap at login regardless of what
# this module says, so flipping the option below to `false` would look like a
# no-op until someone finds the orphaned agent.
#
# `enableKeyMapping` is not optional decoration: without it nix-darwin emits
# an empty activation script and warns, and the mapping silently never lands.
#
# SCOPE: hidutil's UserKeyMapping applies to every keyboard. There is no
# per-device matching here (`hidutil --matching` can do it, nix-darwin's
# option cannot), which is why Karabiner must not ALSO swap ⌘/⌥ for the
# Moonlander — the two stacked, and ⌘Q stopped quitting apps. The Moonlander
# device entry in modules/home/darwin/karabiner/karabiner.json is deliberately
# left with empty `simple_modifications` for that reason; the keyboard does
# its own remapping in firmware.
#
# Applied by `system.activationScripts.keyboard`, which runs on every switch
# and — because /Library/LaunchDaemons/org.nixos.activate-system.plist is
# RunAtLoad — on every boot. That matters: hidutil mappings live in the HID
# layer and do not persist across a reboot on their own.
#
# Mac-mini-only on purpose. The MacBook's built-in keyboard already has an
# Apple modifier layout, where this swap would be actively wrong.
_: {
  flake.modules.darwin.keyboard = {
    system.keyboard = {
      enableKeyMapping = true;
      swapLeftCommandAndLeftAlt = true;
    };
  };
}
