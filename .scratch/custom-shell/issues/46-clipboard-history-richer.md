# Launcher clipboard history: images, pins, aliases and full-text search

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

More for the `cc` mode of issue 07: image previews, pinned entries that outlast the
history, aliases that find a pin by name, and search through an entry's whole text.

- ambxst keeps its own SQLite history with pins and aliases, and its Clear keeps the
  pins (`modules/services/ClipboardService.qml`). Ideas only.
- Today `launcher/ClipboardMode.qml` runs `cliphist list` as the mode opens and
  filters the previews with `fuzzy.js`. Images show as "Image". cliphist keeps the
  newest 500 copies, text and images.
- cliphist 0.7.0 (read in its source) has `store`, `list`, `decode`, `delete` (ids on
  stdin), `delete-query` and `wipe`; it has no pins or aliases. `list` collapses
  whitespace and cuts each preview at `-preview-width` (100). An image's preview is
  `[[ binary data <size> <format> <w>x<h> ]]`.

## Proposed choices

1. **Keep cliphist, and keep pins in a file of the shell's own**,
   `Quickshell.statePath("clipboard-pins.json")`, with images beside it in
   `clipboard-pins/`. A pin holds its own copy, so it outlasts the 500 cap and Clear.
   Alternative: a Rust store of our own in place of cliphist, like ambxst's SQLite.
   Reason: cliphist already records on events, caps the history and skips secrets.
2. **Pins come first in the mode.** The row options (issue 47) give Pin, Unpin and
   Delete (`cliphist delete`). Clear keeps the pins.
3. **Aliases on pins only**, set with an "Alias" option that asks for text (issue 47).
   The alias is the row's title, with the text under it, and a match on it ranks first.
   Reason: an unpinned entry can fall off the history.
4. **Image rows show a thumbnail**, in rows twice as tall (96 pixels). As the mode
   opens, one script decodes the images it has not seen (`cliphist decode <id>`) into
   `~/.cache/custom-shell/clipboard/<id>`, and removes ids that cliphist no longer
   lists. Clear removes them all. `Image` scales them with `sourceSize`, so ImageMagick
   (gone after issue 23) is not needed. Setting `clipboard.imagePreviews` (on).
   Alternative: decode each image as its row scrolls into view.
5. **Full-text search with `cliphist list -preview-width 2000`.** Each query word must
   appear in the text, ignoring case, and the order stays newest first. Alternative:
   today's fuzzy match over 100 characters. Reason: a subsequence match over 2,000
   characters matches nearly anything.
- The setting goes under a Clipboard heading on the Launcher page.
- Cost: `cliphist list` and the image script when the mode opens. Nothing runs in the
  background, so nothing in game mode.

## Acceptance criteria

- [ ] A copied screenshot shows as a thumbnail. Choosing it puts the image back on the
      clipboard (wl-copy guesses its type with xdg-mime, on both hosts).
- [ ] A word from the middle of a long copied text finds it.
- [ ] A pin stays after the cap drops its entry and after Clear. Unpin removes it.
- [ ] An alias finds its pin first, and Enter copies the pin's text.
- [ ] Delete removes one entry from cliphist. Clear deletes the cached thumbnails too.
- [ ] Tests use a scratch history (`CLIPHIST_DB_PATH`, as issue 07 did) and put the
      clipboard back.

## Blocked by

- .scratch/custom-shell/issues/47-per-app-actions.md
