# Theme colours that read well in every scheme

Status: ready-for-human
Type: HITL (how the schemes look is a judgement)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Some schemes look bad, and some states disappear in them. The user, 2026-10-23: "we'll
need to look at the themes and fix these issues. some themes look quite bad."

What is measured (`.scratch/custom-shell/theme-contrast.py` on the current wallpaper,
every scheme in both modes, matugen `--dry-run`, so the live theme is untouched):

- **`Theme.subtext` is never dimmer than the text.** It is matugen's `on_surface`, which
  equals `on_background` (`Theme.text`) in all 16 schemes and modes (contrast 1.00).
  Every secondary line drawn in it (62 uses) shows at full strength.
  `on_surface_variant` is a dimmer colour in every scheme (1.32 in dark, about 1.84 in
  light).
- **In dark mode the primary colour is hardly lighter than the text** (1.18 to 1.32). A
  state shown only by turning something the primary colour relies on hue.
  `scheme-monochrome` has none (primary `#ffffff` beside `#e2e2e2` text), and `content`
  and `fidelity` very little (`#fff2eb` beside `#e7e1df`). The recording microphone
  (issue 40) disappeared in monochrome for this reason and now uses `Theme.error`.
- **`content` and `fidelity` give the same colours** in both modes for this wallpaper.
- **`Theme.error` stays red** in every scheme (`#ffb4ab` dark, `#ba1a1a` light).

Not yet known: which schemes the user finds bad, and why. It may be these contrasts, or
other things (the frame's or the bar's colours, the light modes, a wallpaper whose
colours do not suit a scheme).

## Questions for the user

1. Which schemes look bad, in which mode, and with which wallpaper? A screenshot or a
   few words each (for example "monochrome dark: can't tell what's selected").
2. Should the picker offer fewer schemes? `content` and `fidelity` gave identical colours
   here; that may hold for most wallpapers. Check with two or three more wallpapers
   (`theme-contrast.py <image>`) before dropping one.
3. For secondary text: `on_surface_variant` (a slightly dimmer colour from the scheme) or
   the text colour at an opacity (for example 70 %)?

## Leads

- Map `subtext` to `on_surface_variant` in `quickshell/matugen/colors.json` (or point
  `Theme.subtext` at `overSurfaceVariant`), then look over the 62 uses.
- Find every state shown only by colour (primary text or icons: the active workspace,
  selected rows, chips) and give each a second cue that does not depend on hue: a fill,
  weight, an outline or a glyph.
- Check the light modes on screen; nothing above was judged by eye.

## Acceptance criteria

- [ ] The user has named the schemes that look bad and what is wrong with each.
- [ ] Secondary text is visibly dimmer than primary text in every scheme and mode.
- [ ] Every state the shell shows (selected, active, muted, recording, on/off) can be
      seen in `scheme-monochrome`, dark and light.
- [ ] `theme-contrast.py` shows no pair the shell relies on at 1.00.
- [ ] The user is happy with each scheme they keep in the picker.

## Blocked by

- .scratch/custom-shell/issues/83-theme-compare-tool.md (judge the schemes with it; parked until then, 2026-10-23)
