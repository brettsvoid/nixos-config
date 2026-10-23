# Backend: wallpaper folders, OLED and Tint

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `wallpapers`.

The Wallpapers view gets ambxst's search, filter chips, OLED and Tint. Search is
frontend-only. The rest needs Rust (lib.rs: `wallpapers_dir`, `list_wallpapers`,
`set_wallpaper`, `ThemeState::resolve`, `reload_theme`).

- **Folder and filters.** A config key `wallpaper.folder` (default `~/Pictures/
  Wallpapers` in config.default.json) replaces the hardcoded path. `list_wallpapers`
  also lists images one level down, and each `Wallpaper` gains `folder` (the top-level
  subfolder, "" at the root) and `kind` (lower-case extension), per ipc.ts.
- **OLED.** A config key `appearance.oled` (bool, default false). On, the dark scheme's
  surface becomes pure black: replace the dark palette's `base` with `#000000` before the
  roles resolve, so every role built on it follows. Light mode is unaffected.
- **Tint** (ambxst's `palette.frag`: the desktop wallpaper repainted in the theme's own
  colours, a soft snap of each pixel to the nearest palette colour, weighted
  `exp(-k · distance²)`). A config key `wallpaper.tint` (bool, default false). On, after
  the palette for a wallpaper is known (generated from the ORIGINAL image, as today),
  write a tinted copy under `~/.cache/edgebar/tinted/` (scaled to the largest screen, not
  the source size) and set that as the desktop. Off sets the original again. Remember
  the original (a sidecar file there), so `current_wallpaper` answers with the original
  and the grid highlights the right thumbnail. When the palette changes (scheme,
  appearance, OLED) while tint is on, re-tint. Protect against the launchd watcher
  (`modules/home/darwin/edgebar.nix`, `edgebar-wallpaper-theme`) re-theming from the
  tinted image: it already skips runs within 3 s of the `.inapp-change` marker; touch the
  marker before each desktop change. Choose `k` so the result is posterised but smooth,
  and show one result by reading the PNG with your Read tool. Measure the time in the
  dev build: it must finish within 3 s at 2880 px wide (opt-level overrides for the
  image crates in `[profile.dev.package.*]` are fine). HEIC may not decode: then tint
  skips it and says why.
- Don't change Brett's desktop wallpaper or settings while testing: write tinted copies to
  a temp dir in tests and run desktoppr only in a test that sets the wallpaper back to
  what `desktoppr` reported before.
