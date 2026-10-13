# Notification history kept across restarts

Status: ready-for-human
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Today the history is the notification server's live list, so a shell restart (and
every rebuild, see below) empties it. A restart should not empty it.

- Keep the history in a file in the shell's state, and load it at start.
- A notification leaves the history when you dismiss it (its ×, or Clear all), when
  you run one of its actions (clicking it), or when its app withdraws it, as in
  Caelestia.
- After a restart the app can no longer be reached, so a restored notification shows
  without action buttons and clicking it does nothing.
- Images that apps send as data (not as a file) only exist while the notification is
  live. Save them to the state directory, so a restored notification keeps its image.
  Remove the file when its notification leaves the history.
- An app replacing its notification (the same id) updates the entry and is saved.

**State directory.** Quickshell names a shell's state directory after a hash of its
config's path, which is a new store path on every rebuild. So app-usage counts and the
do-not-disturb setting already restart from nothing after each rebuild. Five such
directories exist in `~/.local/state/quickshell/by-shell/`. Pin the shell's id and put
its state in `~/.local/state/custom-shell/`, beside `wallpaper.json`, then move the
newest existing files there.

## Acceptance criteria

- [ ] Notifications in the history are still there after the shell restarts, with
      their app name, summary, body, icon or image, and urgency.
- [ ] They are still there after a rebuild changes the shell's store path.
- [ ] Dismissing one, or Clear all, removes them for good, including after a restart.
- [ ] An app withdrawing its notification removes it from the history.
- [ ] Actions work while the notification is live; restored ones show none.
- [ ] An image sent as data is still shown after a restart.
- [ ] App-usage counts and do-not-disturb survive a rebuild.

## Blocked by

- .scratch/custom-shell/issues/08-notifications.md

## Comments

**2026-10-13:** Built, not yet committed. A game was running fullscreen, so the shell
was not swapped in on screen. The services were tested headless instead: a copy of the
shell on a private D-Bus session bus, with Qt's offscreen platform.

- **Checked headless:**
  - The history is saved, and comes back after a restart without actions.
  - An app withdrawing its notification (CloseNotification) removes it from the
    history and from the saved file. At first it was kept, so it could only be
    cleared by hand. After looking at what other systems do, you chose Caelestia's
    behaviour instead.
  - A replaced notification (`notify-send -r`) updates its entry in place.
  - Running an action removes it, and the app gets the action. Dismiss and Clear all
    remove entries for good, and their image files.
  - Transient notifications are not saved.
  - An image sent as data is saved: a 16×16 PNG with exactly the colour sent.
  - A reload re-links the live notifications to their saved entries, with no
    duplicates, and doesn't show their pop-ups again.
- **Found on the way:**
  - On a reload, Quickshell hands the live notifications back through
    `onNotification`, marked `lastGeneration`. The old code showed their pop-ups a
    second time.
  - Restoring the saved list needs `Array.from`, because `JsonAdapter` gives back an
    array-like value rather than an Array.
- **State directory:** it is pinned with `//@ pragma ShellId custom-shell` and
  `//@ pragma StateDir $BASE/custom-shell`. `app-usage.json` and `notifications.json`
  were copied there from the newest old directories. The old
  `~/.local/state/quickshell/by-shell/*` directories are still there and can go.
- **Left for you:** look at the history drawer and pop-ups in the real shell after a
  restart (`toggle-shell custom`, then `toggle-shell restart`). Restored cards should
  show no buttons, and an image sent as data should still show.
