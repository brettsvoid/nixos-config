# Notifications: pop-ups and history

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

The shell becomes the notification server (Quickshell's Notifications module). New
notifications pop out of the frame below the bar, stack, and expire after a timeout
unless they are critical. A history drawer (Super+N, as in Caelestia) lists past
notifications grouped by app, with dismiss and clear-all.

Support what apps commonly send: app icon, image, body markup, action buttons, and
urgency. Add a do-not-disturb toggle that keeps notifications in the history without
showing pop-ups.

Only one program can own the notification service. While the custom shell runs it owns
it; `toggle-shell` already stops the other shells first.

## Acceptance criteria

- [ ] `notify-send` with a summary, body, icon and an action shows a pop-up from the
      frame; clicking the action runs it.
- [ ] Normal notifications expire; critical ones stay until dismissed.
- [ ] Several notifications at once stack without overlapping.
- [ ] Super+N opens the history; entries can be dismissed singly or all at once.
- [ ] Do-not-disturb hides pop-ups but still records them.
- [ ] Nothing animates while no notification is showing.

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop with `notify-send`.
- `services/Notifications.qml` holds Quickshell's NotificationServer (markup, links,
  actions, images, persistence; `keepOnReload`). Every notification is tracked into the
  history; a pop-up shows unless do-not-disturb is on, and critical ones always show.
  Pop-ups hide after the app's timeout (the D-Bus value is milliseconds; 5 s when it
  gives none), except critical and resident ones; hovering pauses the timer. The history
  keeps everything until dismissed. Do-not-disturb is saved in
  `statePath("notifications.json")`.
- Pop-ups: a Drawer from the top edge aligned to its end, which runs into the frame's
  top-right corner and stacks newest first. Drawer gained `align` (start/centre/end)
  and eases changes to its content's size, so a new card slides in from under the bar.
  Pop-ups wait while another drawer is open on that screen (on the portrait screen the
  launcher would overlap them).
- History: Super+N (beside Caelestia's sidebar bind), a Drawer from the right, grouped
  by app (latest app first), with × per entry, Clear all, and the do-not-disturb toggle.
- Checked: icon, summary, body markup and two actions showed; clicking Open printed
  `open` from `notify-send -A` and closed it; three at once stacked without overlap; the
  1.5 s one left on time, the critical one (red outline) stayed; the history listed
  everything by app, × and Clear all worked; with do-not-disturb on a normal one went
  only to the history and critical ones still popped up; an `image-path` hint replaced
  the icon. No frames were drawn in 8 s with no pop-up showing. Qt's JavaScript has no
  `Array.prototype.flatMap`; the history uses loops.
- The first pop-up after the shell starts (or reloads) takes about half a second longer
  while Qt loads the card's QML; later ones are fully out within 300 ms.
- Ownership: mako starts by D-Bus activation whenever nothing owns
  org.freedesktop.Notifications, and has owned it all session on the desktop, Caelestia
  included (it started at 21:12 with the session). The server takes the name as soon as
  mako lets go, so `toggle-shell custom` now stops mako after starting the shell;
  tested with mako running first.
