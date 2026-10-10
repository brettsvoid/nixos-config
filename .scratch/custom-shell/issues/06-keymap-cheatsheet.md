# Keymap cheatsheet panel, replacing the Fuzzel one on Super+/

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop, except removing Fuzzel and
`hypr-cheatsheet`, which stay as fallbacks (below).
- `cheatsheet/Cheatsheet.qml` is a Drawer from the top edge. Each time it opens it runs
  `hyprctl binds -j` once and lists every bind as key caps and a description, in
  sections; typing filters on all the words given, across keys, description and group.
- `cheatsheet/binds.js` decodes the mod mask (64 Super, 4 Ctrl, 8 Alt, 1 Shift), names
  mouse, media and named keys ("Left click", "Volume up", "Caps Lock", "Space"), and
  describes binds that have no description from their dispatcher. Live, two binds have
  none: Caelestia's runtime Caps_Lock/Num_Lock binds, shown as their global's name.
- Grouping needs no new convention: the group comes from what the bind does, the
  dispatcher (exec → Apps, global → Shell, window dispatchers → Windows, workspace ones
  → Workspaces, exit → Session), and the key for media (XF86…) and screenshots (Print).
  New binds from other modules land in a group without changes here.
- Checked: opened on `global custom-shell:cheatsheet`; filters "click" (the two mouse
  binds), "volume", "move 3" and "lock" each showed the right rows.
- **Change from the brief:** Super+/ and Super+R run `custom-shell-or <drawer>
  <fallback>`, which opens the drawer when the custom shell's global shortcut is
  registered and runs the fallback otherwise (`hypr-cheatsheet`, Fuzzel). Removing
  them now would take both keys away from Caelestia and the laptop before the custom
  shell is the daily shell. The built helper opened the drawer with the shell running
  and ran `hypr-cheatsheet` with it stopped. Issue 22 binds the globals directly and
  removes Fuzzel and `hypr-cheatsheet`.
