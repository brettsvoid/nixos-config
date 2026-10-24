# UI: the dashboard's toggles, calendar and notification history

Read `briefs/_ui-common.md` first; its rules apply. Unit name: `ui-info`. You replace
`src/notch/dashboard/toggles.ts`, `calendar.ts` and `notifications.ts` (and their CSS).
Backends merged: `toggles`, `set_toggle`, the `toggles` event (`src-tauri/src/
toggles.rs`); `notification_history`, `notification_dismiss`, `notification_clear`
(`src-tauri/src/notifications.rs`). Read their module docs for what each state means.

## Quick toggles (top of the middle column)

Five square buttons in a row: Wi-Fi, Bluetooth, Focus, Night Shift, Caffeine (AirDrop
was dropped: decisions.tsv says why). Off: `--surface-container`, full-round. On:
`--primary` fill with `--on-primary` glyph and a slightly squarer radius, the change
animated quickly (ambxst's active pattern). Glyph per state (Wi-Fi off, Bluetooth off, a
moon for Focus, a sun-horizon for Night Shift, a coffee cup for Caffeine). The tooltip is
"<name>: <detail>". Click → `set_toggle`, updating at once and correcting from the reply.
An `available: false` toggle is dimmed; clicking it explains (its `detail`) and offers
the matching System Settings pane. Right-click on any toggle opens its pane. Opening a
pane needs a small Rust command: add `open_settings_pane { pane }` with a fixed
whitelist of `x-apple.systempreferences:` URLs (Wi-Fi, Bluetooth, Focus, Displays for
Night Shift, Privacy › Full Disk Access, Privacy › Bluetooth) to lib.rs and ipc.ts.
Re-read `toggles` on `show`; listen to the event.

## Calendar (under the toggles, a square card)

A month viewer like ambxst's and the custom shell's (`modules/home/desktop/quickshell/
dashboard/Calendar.qml`): a header with "Month yyyy" (bold) and two chevron buttons;
weekday initials (week starts Monday by default; add a setting `calendar.weekStart`,
"monday" | "sunday", default in config.default.json); always six week rows, so it never
changes height; today is a `--primary` circle with `--on-primary` digits; days from the
neighbouring months dimmed; the current week's row on a faint `--surface-container` band.
The wheel over the grid moves a month; clicking the title returns to today. There are no
events (decisions.tsv explains); don't fake any. Re-render at midnight if the notch is
open (one timer to the next midnight, not a poll).

## Notification history (the flexible third column)

- Header: "Notifications", a bell button that is the Focus toggle (`set_toggle focus`,
  showing the same state and availability as the quick toggle), and a clear-all button.
- Grouped by app, newest app first: a group header with the app's icon, name and a count
  chip; a group of one is shown expanded; others expand and collapse on click. An entry:
  icon, title (bold), subtitle, body up to three lines, relative time ("now", "5m",
  "2h", "3d"). Hovering an entry shows a dismiss button; dismissing slides it out and
  calls `notification_dismiss`. Clear all cascades the groups out (about 80 ms apart),
  then calls `notification_clear`.
- Empty: a quiet bell-off icon and "No notifications". `access: "denied"`: say edgebar
  needs Full Disk Access to read macOS's notification history, with a button that opens
  that Privacy pane. `"unavailable"`: say macOS's history store wasn't found.
- Read on `show`, then every 15 s while the dashboard shows; stop on `hide`.
- Opt-in: a setting `notifications.history` (default false in config.default.json) gates
  every read. Off, the column says macOS notification history can show here and offers to
  turn it on (it reads macOS's notification store, which needs Full Disk Access). Never
  turn it on yourself: Brett decides, and an agent must not view his real notifications.
  Prove the on state with literal data only.

Proof: snap the real column in its default off state, and render the empty, denied and
grouped states with literal data through eval.
