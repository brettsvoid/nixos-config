# A tool to compare themes in one view

Status: ready-for-human
Type: HITL (the lab's look and the open questions are the user's call)

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
   puts each surface in each of its states (open, hover, selected, muted, recording,
   error, empty, and so on) and writes one page of screenshots with the contrast numbers
   beside each theme. No shaders in software rendering: the frame, the lock blur and the
   effect previews are missing, and the page says so. The lab covers those.

16 themes per wallpaper (8 schemes by 2 modes) is too many to show whole shells side by
side at once; the lab shows a chosen few, the gallery shows them all.

## Still to ask

- Do GTK apps, terminal colours and window borders count as "UI for the shell"? They are
  themed from the same matugen run but are not drawn by Quickshell. Out unless the user
  says so.
- Which wallpapers to compare: a folder, or a list in the settings?
- Should the gallery list every state by hand, or should each surface declare its
  states so the script finds them (fewer to forget, but more code in each surface)?

## Acceptance criteria

- [ ] The lab shows any surface under any chosen themes side by side, with hover, click
      and shaders working, and the contrast numbers for each theme.
- [ ] The gallery shows every surface in each of its states under every scheme, mode and
      wallpaper, with the contrast numbers.
- [ ] With the lab closed, the shell uses no more memory than before.
- [ ] Building it changes nothing in the live theme, settings or session.
- [ ] Adding a scheme or a wallpaper to the comparison needs no code change.

## Blocked by

- None
