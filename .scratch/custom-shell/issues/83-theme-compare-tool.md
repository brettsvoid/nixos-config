# A tool to compare themes in one view

Status: ready-for-human
Type: HITL (what the view should show is the user's call)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A tool that shows how the shell looks under every theme at once, so schemes, modes and
wallpapers can be compared side by side and issue 82 can be judged by eye. The user,
2026-10-23: "I actually want to build some tooling so I can compare every aspect in one
place/view."

What exists to build on:

- `.scratch/custom-shell/theme-contrast.py` gives every scheme's colours for a wallpaper
  with matugen `--dry-run`, without touching the live theme.
- `theme/Theme.qml` reads all colours from `~/.cache/qs-theme/colors.json`, written from
  `quickshell/matugen/colors.json`.
- `qs-test` runs the whole shell headless and takes screenshots, but renders in software:
  no `ShaderEffect` or `MultiEffect`, so the frame, the lock screen's blur and the effect
  previews are missing (`docs/quickshell-notes.md`).

## Two ways to do it (to settle before building)

1. **A gallery of screenshots.** A script runs `qs-test` once per scheme, mode and
   wallpaper with that theme's colours, opens the parts to compare (bar, each drawer,
   the settings window, notifications, the OSD) and writes one page or contact sheet.
   Uses the real shell, so nothing drifts; no shaders; a full run takes minutes.
2. **A theme lab inside the shell.** A window (a settings page, or `custom-shell theme
   lab`) that draws the real components side by side, each under its own palette, live
   on the GPU. Needs `Theme` to be swappable per subtree instead of one singleton, which
   touches every component that reads it.

A first prototype of either would show which is worth it.

## Questions for the user

1. What does "every aspect" cover? The bar, drawers, settings window, notifications,
   OSD, lock screen, GTK and terminal colours, window borders?
2. Compare across what: schemes, light and dark, wallpapers, or all three at once?
3. Is a static picture enough (gallery), or do you want to hover and click in it (lab)?
4. Should it also print the numbers from `theme-contrast.py` beside each theme?

## Acceptance criteria

- [ ] One view shows the chosen parts of the shell under each chosen theme.
- [ ] Building it changes nothing in the live theme, settings or session.
- [ ] Adding a scheme or a wallpaper to the comparison needs no code change.

## Blocked by

- None
