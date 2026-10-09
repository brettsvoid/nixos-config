# Notifications: pop-ups and history

Status: ready-for-agent
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
