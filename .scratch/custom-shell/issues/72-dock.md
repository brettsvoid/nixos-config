# Dock

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

App icons that grow out of the frame's bottom edge: pinned apps first, then other
running apps, with a dot per open window. ambxst: `modules/dock/` (on the Overlay layer,
which this shell never uses; ideas only). Issue 47 gives launcher rows an options list
and leaves the pinned list to this issue (its choice 5).

It builds on the Drawer, `ToplevelManager.toplevels` (app id, title, `activated`,
`activate()`, `close()`), `DesktopEntries.heuristicLookup(appId)` for icons, and the
launcher's way of starting an app (`launcher/AppsMode.qml`, which also counts the use).

## Proposed choices

1. **Off by default** (`dock.enabled`, `false`): this desktop tiles, and the launcher
   and bar already start and find apps.
2. **When on, it hides until wanted.** It rises after the pointer rests 300 ms on the
   frame's bottom band and goes 400 ms after it leaves, like the auto-hidden bar. The
   delay stops it rising when the pointer only passes. `dock.autoHide` (`true`).
   Alternative: always shown, with the bottom edge reserved (then choice 8 needs its
   alternative).
3. **Edge:** the bottom, or the top while the bar is at the bottom.
4. **Screens:** every screen, by name as the bar does (`dock.hiddenScreens`, `[]`).
   Each lists every app, wherever its windows are.
5. **Pins:** desktop entry ids in a list setting, `dock.pinned` (`[]`), so Nix can set
   them. This issue adds "Pin to dock" and "Unpin from dock" to issue 47's app options
   in the launcher, and "Unpin" to the dock's own menu; dragging an icon reorders pins.
6. **Running apps** grouped by app id: up to 3 dots under the icon, a wide dot for the
   focused app. An app with no desktop entry (a Steam game's `steam_app_…`) shows a
   generic icon, with its window title as the tooltip.
7. **Clicks:** left starts a closed app, focuses a running one's last window, then the
   next. Middle starts another instance. Right opens a menu: pin or unpin, issue 47's
   actions, close all windows. No magnifying: a hover highlight only.
8. **The bottom edge is shared:** the OSD sits at the bottom centre and issue 67's
   toasts at the bottom right. By the numbers, a 10-icon dock (about 510 px) covers the
   OSD's place and reaches the toasts' corner on the 1080-px Dell. While the dock is up
   on a screen, the OSD and toasts there wait; their time runs. Alternative: they grow
   out of the dock's top edge (unchecked how the shapes would join).
9. **Look:** 40 px icons (`dock.iconSize`, 32 to 64, step 4) in one Drawer, joined to
   the frame. It needs a frame shape slot: issue 67's change, made by whichever issue
   comes first.
10. **Game mode and fullscreen:** the frame's band is gone (`reveal` 0), so it cannot
    rise; an open dock closes.
11. **Settings** on the "Desktop" page (shared with issue 71): the five keys above.
    **Cost:** while hidden, only the band's hover handler; icons exist only while it
    shows. No process; no timer beyond the two delays.

## Acceptance criteria

- [ ] Off by default: nothing changes until `dock.enabled` is on.
- [ ] Resting the pointer on the bottom edge raises it; passing over does not.
- [ ] Pins come first; a running app shows a dot per window, up to 3. Clicks start,
      focus and cycle windows as above; middle click starts another.
- [ ] Pins survive a restart; `local.customShell.settings.dock.pinned` sets them.
- [ ] Volume keys while the dock is up show the OSD after it hides, if still in time.
- [ ] Costs nothing in game mode or with a fullscreen window: it cannot rise.

## Blocked by

- .scratch/custom-shell/issues/47-per-app-actions.md (for the launcher's "Pin to dock")
