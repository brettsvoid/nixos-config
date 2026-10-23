# A tool to compare themes in one view

Status: ready-for-human
Type: HITL (the lab's look is the user's call)

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

## The user's answers (2026-10-23)

1. **What it covers:** "literally everything related to UI for the shell." Every surface
   under `quickshell/`: the bar, the frame, the dashboard, the launcher, the cheatsheet,
   notifications, the OSD, the session menu, the lock screen, the settings window, and the
   shared components in `components/`.
2. **Compare across:** schemes, light and dark, and wallpapers, all three.
3. **Static or interactive:** both. Hover and click in it, and also a static picture of
   each state.
4. **Contrast numbers:** yes, beside each theme (from `theme-contrast.py`).

## Plan (from the answers)

Both approaches, since the user wants both kinds of view:

1. **Theme lab (interactive).** An on-demand window (`custom-shell theme lab`) that draws
   the real components, each panel under its own palette, live on the GPU, so shaders
   and hover and click work. Pickers choose the scheme, mode and wallpaper for each panel;
   the panel shows the theme's contrast numbers. Loaded by a `Loader` and unloaded when
   closed, so it costs nothing otherwise (issue 80, lean shell).
   - Needs `Theme` swappable per subtree. Today `theme/Theme.qml` is a singleton, read by
     61 QML files. One way: components read colours from an attached or inherited
     palette object that falls back to the singleton, so the live shell does not change.
     Settle this in a prototype on one or two components before touching the rest.
   - Palettes come from matugen `--dry-run`, as in `theme-contrast.py`, so the live theme
     and `~/.cache/qs-theme` are untouched.
2. **State gallery (static).** A script runs `qs-test` per scheme, mode and wallpaper,
   puts each surface in each state it declares (open, hover, selected, muted, recording,
   error, empty, and so on) and writes one page of screenshots with the contrast numbers
   beside each theme. No shaders in software rendering: the frame, the lock blur and the
   effect previews are missing, and the page says so. The lab covers those.

16 themes per wallpaper (8 schemes by 2 modes) is too many to show whole shells side by
side at once; the lab shows a chosen few, the gallery shows them all.

## The user's second answers (2026-10-23)

- **The theme lab is fine** as planned.
- **GTK apps and window borders count.** Not asked about again: terminal colours (left
  out until the user says).
- **Wallpapers:** "whatever the shell shows": the wallpaper picker's folder, the
  `wallpaper.folder` setting (default `~/Pictures/Wallpapers`, read by
  `dashboard/WallpaperTab.qml`). No separate list.
- **States:** each surface declares its own states; the gallery finds them.

## How GTK and the borders fit in

- **Window borders** are set by `theme/WindowBorders.qml` with `hyprctl keyword` from
  `surfaceContainer`, `primaryContainer` and `primary`. The lab must not call `hyprctl`
  (that changes the live borders); it draws a sample window edge with the same gradient
  from each panel's palette. Lead: move the colour strings out of `WindowBorders.qml`
  into something both can use, so they cannot drift.
- **GTK apps** draw with the named colours in `matugen/gtk.css`, which `generate-theme`
  writes into GTK's config folders. Quickshell cannot draw a GTK app inside its own
  window. Lead (to check before relying on it): write each theme's `gtk.css` to a
  temporary `XDG_CONFIG_HOME` and start a sample app (for example
  `gtk4-widget-factory`) with it, so the live GTK theme is untouched. In the gallery,
  screenshot that app in the headless session beside the shell.

## Acceptance criteria

- [ ] The lab shows any surface under any chosen themes side by side, with hover, click
      and shaders working, and the contrast numbers for each theme.
- [ ] The gallery shows every surface in each of its states under every scheme, mode and
      wallpaper, with the contrast numbers.
- [ ] Both include a sample window border and a GTK app under each theme.
- [ ] The wallpapers compared are the ones in the shell's wallpaper folder.
- [ ] Each surface declares its states; a new state shows in the gallery without editing
      the gallery script.
- [ ] With the lab closed, the shell uses no more memory than before.
- [ ] Building it changes nothing in the live theme, settings or session.
- [ ] Adding a scheme or a wallpaper to the comparison needs no code change.

## Blocked by

- None
