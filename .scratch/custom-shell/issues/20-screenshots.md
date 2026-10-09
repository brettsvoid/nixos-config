# Screenshots without Caelestia

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Move the Print-key screenshots off Caelestia onto plain Hyprland keybinds and small
tools, so they work under any shell. Keep today's behaviour, which follows macOS:

- **Print:** freeze the screen, pick a region (clicking a window selects the whole
  window), open it in swappy to mark up and save.
- **Ctrl+Print:** the same region pick, straight to the clipboard.
- **Shift+Print:** the whole focused monitor to the clipboard, with a notification that
  offers Open (swappy) and Save.

Swappy's config (save to `~/Pictures/Screenshots`) moves with it. Freezing the screen
before picking matters: it captures what was there when the key went down.

## Acceptance criteria

- [ ] All three keys work under the custom shell and under Caelestia.
- [ ] Region pick freezes the screen first, and clicking a window selects that window.
- [ ] Clipboard shots paste into an image-capable app.
- [ ] The monitor shot's notification Open and Save actions work.
- [ ] Saved shots land in `~/Pictures/Screenshots`.
- [ ] Each bind has a description, so it shows in the cheatsheet.

## Blocked by

None - can start immediately.
