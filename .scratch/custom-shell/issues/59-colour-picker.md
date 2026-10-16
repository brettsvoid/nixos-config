# Colour picker

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Pick the colour of any pixel on screen and copy it. ambxst has one in its tools menu
(`modules/widgets/tools/ToolsMenu.qml`, through grim, slurp and ImageMagick); ideas
only.

Checked:

- hyprpicker 0.4.7 is in nixpkgs. It is already in the closure: grimblast's
  `--freeze` (the screenshot keys, issue 20) runs the same store path. It is not on
  `PATH`.
- It freezes the screens and shows a zoom lens. A click or Enter picks; the arrow keys
  move one pixel; Escape quits with exit code 2. It prints the colour (`-f hex`, `rgb`,
  `hsl`, `hsv` or `cmyk`; `-l` for lowercase hex).
- It draws an Overlay-layer surface only while picking, so nothing stays mapped.
- From Hyprland's code (unchecked on screen): it reads the frame before a night
  light's colour matrix (issue 58), so it gives the true colour.

## Proposed choices

1. **A `colour-pick` script in `screenshots.nix`**, beside `screenshot`, for both hosts
   and any shell. It runs hyprpicker, copies the result with wl-copy and sends a
   "Colour copied" notification with the value. Escape copies nothing and sends
   nothing. Alternative: the shell runs hyprpicker as a Process. Reason: it works
   under any shell, like the screenshot keys.
2. **Lowercase hex (`#a1b2c3`).** Setting `tools.colourFormat` (`hex`, or `rgb`, `hsl`)
   on a new Tools page, shared with issue 57. The script reads it with jq, as
   `generate-theme` reads `wallpaper.folder`. Alternative: hex only, no setting.
3. **No history of its own.** cliphist keeps each copied value, so the launcher's `cc`
   mode already lists recent colours. Alternative: a launcher mode of the last ten
   colours with swatches.
4. **Super+Shift+P, and a launcher action "Pick a colour".** Alternative:
   Super+Shift+C, one slip from Super+C, which closes the window. Both are free today.
5. **A plain-text notification.** Alternative: a colour swatch in it, either an image
   the script makes (ImageMagick on its `PATH`) or a special case in the shell's
   notification card. Reason: the value is what gets pasted.
6. **Cost:** nothing runs until a pick. Game mode changes nothing.

## Acceptance criteria

- [ ] Super+Shift+P freezes the screens; a click copies the colour under the pointer
      in the chosen format and shows it in a notification.
- [ ] Escape cancels: nothing is copied, and there is no notification.
- [ ] The arrow keys and Enter pick by keyboard.
- [ ] It works on both monitors, including the rotated DP-2.
- [ ] A new `tools.colourFormat` applies to the next pick.
- [ ] The launcher action works, and the bind shows in the cheatsheet.
- [ ] Nothing runs while not picking.

## Blocked by

- None
