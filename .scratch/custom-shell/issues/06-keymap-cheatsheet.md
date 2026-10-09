# Keymap cheatsheet panel, replacing the Fuzzel one on Super+/

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Super+/ opens a cheatsheet of every Hyprland keybind in the shell's own style, as a
panel growing out of the frame. It replaces the `hypr-cheatsheet` script, which pipes
`hyprctl binds -j` through jq into `fuzzel --dmenu`.

- Read the binds once each time the panel opens (one `hyprctl binds -j` per open is fine;
  this is a user action, not a Hyprland event).
- Show each bind as its key combination (modifiers decoded from the mod mask: 64 Super,
  4 Ctrl, 8 Alt, 1 Shift) and its description. Every bind in the config has a
  description (`bindd`), and the current script has fallbacks for binds that don't.
- Group binds in a way that reads well (by purpose rather than by modifier). If
  grouping needs information the binds do not carry, propose a convention for the
  descriptions.
- Typing filters by key or description.

Once this lands, nothing uses Fuzzel any more: remove the package and the old script.

## Acceptance criteria

- [ ] Super+/ opens the cheatsheet; typing filters; Escape closes.
- [ ] Every current keybind appears with a readable key combination and description,
      including mouse and media keys.
- [ ] Binds added by other modules (game mode, screenshots, shell drawers) appear
      without changes to the cheatsheet.
- [ ] Fuzzel and `hypr-cheatsheet` are gone from both hosts.

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md
