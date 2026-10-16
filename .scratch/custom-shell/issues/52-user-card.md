# User card on the dashboard

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A card at the top left of the Overview tab: a round avatar, the user's name, and the
host with its uptime ("brett-desktop · up 3 h 12 min"). Caelestia:
`modules/dashboard/dash/User.qml` (ideas only).

Today, checked on brett-desktop: there is no `~/.face`, no AccountsService icon, and
the passwd entry has no full name (`getent passwd brett`).

## Proposed choices

1. **Where: the Overview's new header row, left, 320 px wide** (as wide as the date
   column under it). The weather card (issue 49) takes the rest of the row. Issue 48,
   choice 1, covers the taller Overview. Alternative: above the date in the left
   column. Reason: the row keeps both columns as they are.
2. **Avatar: `user.avatar`, default `"~/.face"`,** cut round with Quickshell's
   `ClippingRectangle` (one item, not repeated, so PRD rule 5 holds). With no file, the
   name's first letter on a `Theme.primary` circle. `cache: false`, so a new file shows
   the next time the dashboard opens. Alternative: Caelestia's click-to-choose file
   dialog. Reason: a path set in the settings or from Nix needs no dialog window.
3. **Name: `user.name`, default `""`, which shows the login name** (`USER`).
   **Question:** shall Nix set it, for example to "Brett"?
4. **Host and uptime from `/proc/sys/kernel/hostname` and `/proc/uptime`,** read with
   `FileView` (it reads size-0 `/proc` files with a read loop, checked in
   `fileview.cpp`). The uptime is read again on each tick of the Overview's minute
   `SystemClock`, so it adds no timer. Format: "up 12 min", "up 3 h 12 min",
   "up 2 days 4 h".
5. **No click action.** Alternative: a click opens the session menu (which closes the
   dashboard, as one drawer shows at a time).
6. **Settings,** on the Dashboard page's Overview section: `dashboard.userCard`
   (default `true`), `user.name`, `user.avatar`. Issue 70 can use `user.avatar` on the
   lock screen.
7. **Cost:** one small file read a minute while the Overview shows; nothing otherwise.

## Acceptance criteria

- [ ] With no `~/.face`, the card shows the letter; with one, the round picture.
- [ ] The uptime matches `uptime -p` to the minute and moves on while the tab is open.
- [ ] `user.name` and `user.avatar` work from the settings window and from Nix.
- [ ] Left for the user: the round crop on the desktop (`qs-test` draws no shaders, so it
      cannot show `ClippingRectangle`).
- [ ] Nothing runs while the dashboard is closed or in game mode.

## Blocked by

- None. It shares the header row with issue 49; whichever lands first makes it.
