# Screenshots without Caelestia

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop under the custom shell; the test shot
and the clipboard were cleaned up.
- `modules/home/desktop/screenshots.nix` (new `desktop-screenshots`, both hosts): a
  `screenshot region|region-copy|monitor` script on Print, Ctrl+Print, Shift+Print,
  each bind with a description. Caelestia's Print binds and its swappy config are gone
  from caelestia.nix; the swappy config (save to ~/Pictures/Screenshots) moved here.
- Region: grimblast (hyprwm contrib) `--freeze` (hyprpicker) and `area` (slurp with the
  windows as targets, so a click takes the whole window); `edit` opens swappy, `copy`
  copies. grimblast hands the editor a file in /tmp, readable by everyone, and leaves
  it; `DEFAULT_TMP_EDITOR_DIR` now points at the runtime directory.
- Monitor: grimblast saves the focused output to a temporary file, wl-copy puts it on
  the clipboard, and a notification with the shot as its image offers Open (swappy)
  and Save (a copy in ~/Pictures/Screenshots).
- Checked: region-copy froze the screen (hyprpicker and slurp layers up), a click on
  kitty put a 2524×1380 PNG on the clipboard (kitty's exact size); region opened
  swappy; the monitor shot put image/png on the clipboard and showed Open and Save.
  Save, clicked in the history after the pop-up had gone, wrote a 2560×1440 file; Open,
  from a fresh pop-up, opened swappy.
- The custom shell keeps an expired notification (and its buttons) in the history,
  where mako and Caelestia close it, so `notify-send -A` would wait for ever there: the
  script gives up after ten minutes, after which those buttons do nothing.
- Not tested: under Caelestia (needs a rebuild and a shell swap); the script does not
  depend on the shell, only on a notification server with actions.
