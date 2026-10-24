# UI: the Performance chart and the Wallpapers toolbar

Read `briefs/_ui-common.md` first; its rules apply. Unit name: `ui-views`. You replace
the ResourceChart placeholder in `src/notch/performance.ts` and the SearchBar, FilterBar,
OLED and Tint placeholders in `src/notch/wallpapers.ts` (and their CSS). Backends merged:
`metrics_history`, `CpuStat.mem`; `Wallpaper.folder`/`kind`, settings keys `oled`
(top level: `appearance` is already a string), `wallpaper.tint`, `wallpaper.folder` (see
config.default.json and `src-tauri/src/wallpapers.rs`). The settings layer's converge step
doesn't yet react to those three keys: make `set_setting` call `reload_theme` when any of
them changes (that refreshes OLED and runs the tint converge), and prove it live.

## ResourceChart (Performance view, above the metric rows)

CPU and memory as two lines over time, newest at the right, in a `--surface-container`
card: each a 2 px line with a fill under it that fades from about 30 % of its colour to
nothing; CPU in `--primary`, memory in a second token-derived colour that reads in light
and dark (derive it from the theme, e.g. a `color-mix` of `--primary` and
`--on-surface`); faint horizontal grid lines at 25 % steps. A legend with the latest
values. Zoom (ambxst): the wheel over the chart, or − / + buttons, changes how many
samples show (from about 30 s to the whole 10 min); show the span ("2 min"). Seed from
`metrics_history` on `show`, append from `cpu` events while the view shows, stop on
`hide`. Draw on a canvas only when a sample arrives or the zoom changes, never in a loop.
Re-paint on a `theme` event (canvas colours don't follow CSS).

## Wallpapers toolbar

- Search: a full-round text field ("Search wallpapers…") filtering the grid by
  case-insensitive substring of the file name, as you type. Escape clears it. The bar
  window is not focusable, so check that typing reaches the field on this machine; if it
  can't, say so with evidence and find the smallest change that makes it work (the
  window's `focusable` flag is set in tauri.conf.json; flipping it while the notch is open
  and back after is one option; never leave the bar able to steal focus when closed).
- Filter chips (ambxst FilterBar): one chip per file kind present ("JPG", "PNG"…) and one
  per top-level subfolder; multi-select, OR'd together, none selected = all. Inactive
  chips `--surface-container`, active `--primary` with a check that grows in. Hidden when
  there's only one kind and no subfolders.
- OLED and Tint chips: switches bound to `oled` and `wallpaper.tint` through
  settings.ts. OLED is disabled in light mode (it only changes the dark surface). Picking
  or toggling with Tint on returns at once and the desktop changes about 2 s later
  (`current_wallpaper` answers the old original until then), so highlight the clicked
  thumbnail optimistically and show Tint busy until the desktop changes.
- The scheme select, ink control and Browse stay; restyle them to match if the restyle
  didn't.

Don't leave Brett's wallpaper tinted or OLED on: if you flip either to prove it, flip it
back and confirm `current_wallpaper` is what it was before you started.
