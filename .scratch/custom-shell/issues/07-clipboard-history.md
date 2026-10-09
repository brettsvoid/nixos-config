# Clipboard history in the launcher

Status: ready-for-agent
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
