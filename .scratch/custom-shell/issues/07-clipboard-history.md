# Clipboard history in the launcher

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A clipboard history you can search and paste from, as a prefix mode in the launcher
(for example typing `cc` first, as ambxst does). Choosing an entry puts it back on the
clipboard.

Recording must be event-driven: a watcher on the Wayland clipboard
(`wl-paste --watch`) stores each new copy. Nothing polls. Decide in this issue whether
to use an existing clipboard history tool or write a small Rust program, and record why.

- Text first. Images are optional and can be a follow-up if they complicate things.
- Cap the history (by count or age) so it cannot grow without limit.
- If a password manager marks a copy as secret (the `x-kde-passwordManagerHint` MIME
  type), do not store it. Check which tools honour this.
- A way to clear the history.

## Acceptance criteria

- [ ] Copying text in any app adds it to the history within a second, with no polling.
- [ ] The launcher's clipboard mode lists entries newest first and filters as you type.
- [ ] Choosing an entry makes it the current clipboard; pasting gives that text.
- [ ] The history survives a logout and is capped.
- [ ] Secret-marked copies are not stored (if the chosen tool can detect them; otherwise
      note the limitation here).
- [ ] The history can be cleared from the launcher.

## Blocked by

- .scratch/custom-shell/issues/05-launcher-drawer.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop against a scratch history
(`CLIPHIST_DB_PATH`), so the real one was not touched; the clipboard was put back.
- Decision: **cliphist**, not a Rust program of our own. It already does every part:
  `wl-paste --watch cliphist store` records each copy as it happens (no polling); it
  caps the history (`-max-items`, 500 here) and keeps it in `~/.cache/cliphist`, which
  survives a logout; text and images; `list`, `decode`, `wipe`. Secret copies: wl-paste
  2.3.0 sets `CLIPBOARD_STATE=sensitive` when the offer has the
  `x-kde-passwordManagerHint` type (presence only, not its value), and cliphist 0.7.0's
  `store` stores nothing in that state (both read in their sources). It is GPL; we
  only run it.
- Recording: home-manager's `services.cliphist` (text and images), a user service on
  graphical-session.target, so copies are kept under Caelestia and ambxst too. Its
  generated ExecStart is the pipeline tested here.
- Launcher: `launcher/ClipboardMode.qml`, prefix `cc` (ambxst's). Entering the mode
  runs `cliphist list` once; entries are newest first and filtered by the rest of the
  query; choosing one runs `cliphist decode <id> | wl-copy`; the last row clears the
  history (`cliphist wipe`). Modes may now have `refresh()`, called on entering them.
  The apps mode's placeholder mentions `cc`.
- Checked: two `wl-copy`s were in the history within a second; a store with
  `CLIPBOARD_STATE=sensitive` added nothing; `-max-items 3` kept the newest three of
  five; in the launcher, `cc` listed them newest first, `cc first` filtered to one,
  Enter made it the clipboard (`wl-paste` gave it back), and the clear row emptied it.
- Not tested: an actual password manager's copy (the hint path is taken from the two
  sources and cliphist's handling was tested directly).
