# Deslop: the frontend

Unit name: `deslop-frontend`. Read `briefs/_ui-common.md` first; its rules on the live bar,
the debug socket, snapshots and restoring Brett's state apply. Work in the main checkout
(`/Users/brett/nixos-config`, branch `edgebar-notch`) against the live `pnpm tauri dev` in
herdr pane `w1:p4`. Phase A (`briefs/deslop-rust.md`) has already landed; read its commits
(`git log --oneline` since `3d374f4`) so you build on its IPC changes.

Two reviews of this branch found the items below. Each was triaged and accepted; do each
one, or, if reading the code proves an item wrong, skip it and say why with evidence. Keep
behaviour and looks the same unless an item says otherwise.

## Before you change anything

Capture a baseline: `scripts/snap-states.sh <scratchpad>/deslop-frontend/before-dark`,
then the same in light mode (switch through the Settings view and back to auto
afterwards). After the last commit capture `after-dark` and `after-light` the same way and
compare each pair with a pixel diff (e.g. `nix shell nixpkgs#imagemagick -c compare
-metric AE`). Explain every differing region: the clock, CPU figures, the playing media
and the chart move on their own; anything else is a regression or an intended change you
name.

## Items

The view contract and shell (`src/notch/view.ts`, `src/main.ts`)
1. `ViewContext.reportInteractiveRects` and `showView` have no callers, and no widget uses
   its `ctx` argument. Change `Widget` to `(root) => ViewHandle`, shrink `ViewContext` to
   `{ setAlert(reason) }` with the view id bound per view in `mountViews`, and delete the
   id guard in main.ts that this makes dead. Give `resourceChart` a concrete return type so
   `performance.ts` no longer writes `chart.show?.()`.
2. The document click handler's outside-click test uses `d.root.contains(e.target)`, which
   fails when a handler removed the clicked element. Use `e.composedPath().includes(d.root)`.
   Prove it in this WKWebView on the live bar first: click a control that redraws itself
   inside an open drawer (a Setup row's button, a notification group toggle) with the
   `stopPropagation` or in-place redraw workaround removed, and show the drawer stays
   open. Then delete each workaround that existed only for this (the `stopPropagation`
   calls in settings/index.ts, wallpapers.ts and assistant.ts; check each). An in-place
   redraw that also avoids a flicker may stay; say which.
3. Give views a theme hook that main.ts calls after `applyConfig`, and use it in
   resource-chart.ts instead of `on("theme", () => requestAnimationFrame(paint))`, which
   depends on listener order.
4. `NOTCH_CHROME` copies `--drawer-pad`, the `.rail-tab` width and the `.notch-panel` gap
   from CSS by hand: read them from the computed style once, or set the CSS from TS.
5. `FALLBACK` copies config.default.json's geometry: import the JSON as settings.ts does.
6. `clockMinute = -1` forces a repaint: make it explicit (`tick({ force: true })` or similar).
7. The init lines `releaseKeyboard(); void syncWindowHeight();` reset native state after a
   WebView reload: extract a named function.
8. Rename the TS type `Colors` to `Colours` and `applyColors` to `applyColours` (UK
   English). The `colors` key from Rust and JSON stays.

Types at the IPC boundary (`src/ipc.ts`, `src/settings.ts`)
9. `Config.appearance` is `string`: type it `"light" | "dark" | "auto"`. `Config.notchIdle`:
   `"handle" | "clock" | "userHost" | (string & {})` or whatever the Rust side really sends.
10. `Network`: a union keyed on `state`, `rssi` and `online` only where Rust sends them
   (read the Rust struct; narrow the TS type to what is true).
11. Type `SettingsSnapshot.effective` as `Settings` at the boundary and delete the casts in
   settings.ts and settings/rules.ts that this makes unneeded.
12. `isSet` becomes `isOverridden`. `Option.icon` and its branch in rows.ts are dead; so is
   `export const ready` in settings.ts. Exports used only in their own file (`UNDO`,
   `KeyOf`, `Range`, `Field` in rows.ts, `Note` in quick-toggle.ts) lose `export`. The
   fallback colour in resource-chart.ts that `--rc-grid` always overrides goes. `f.sync()`
   on frames with no key does nothing: remove it.

One place for each thing
13. One `el(tag, className?, ...children)` in a new `src/dom.ts`, replacing `el` in
    rows.ts, notifications.ts and markdown.ts, `div` in dashboard/index.ts, and `span` and
    `bubble` in assistant.ts (keep `bubble` if it does more than build an element).
14. One wave stepper: the amplitude and phase step is written in main.ts and player.ts, and
    `WAVE` and `RING` share speed, ease, rampPx and fadeInPx. One module with the stepper
    and the shared constants; each caller keeps its own amplitude, wavelength and geometry.
15. One scheme list and picker builder for wallpapers.ts and settings/index.ts, with one
    CSS rule set (`.st-select` against `.wp-select`/`.scheme-select`). The list is also
    copied in Nix's select-scheme.sh: make one JSON file the source that TS imports and
    edgebar.nix reads (`lib.importJSON`) to build the script's list.
16. One model list for assistant.ts and settings/index.ts, and the idle presets next to it
    stop repeating the option values.
17. One `whyLine()` exported from rows.ts for rows.ts, rules.ts and setup.ts.
18. The player's `AREA`, `C` and `RING.line` are copied into player.css (sizes and
    `stroke-width: 4px`): keep one source, e.g. set CSS custom properties from TS.
19. `rules.ts` `NAMES` copies lib.rs `WS_ORDER`: Phase A exposes the workspace names
    (see its report); read them from there.
20. `SPANS_S` in resource-chart.ts matches metrics.rs's history length by hand: derive the
    largest span from what Phase A's `MetricsHistory` now reports. main.ts
    `CPU_GRAPH.samples` copies `CPU_HISTORY` (its comment still says lib.rs; it moved to
    metrics.rs): use the value Phase A exposes and drop the comment.

CSS
21. One global `[hidden] { display: none !important; }` in styles.css; delete the 31
    per-selector `[hidden]` rules and the specificity workarounds (`#cpu[hidden]`,
    `.view-dashboard` relying on `.view[hidden]`).
22. One pill-button base class for `.st-btn`, `.nf-action`, `.tg-note-open` (identical to
    `.nf-action`), `.browse-btn`, `.as-new`, `.as-retry`, `.wp-chip`, `.wp-switch` where
    their declarations match; one spin keyframes (`wp-spin`, `st-spin`); one scrollbar rule
    (assistant.css, wallpapers.css, dashboard.css, notifications.css).
23. settings.css hard-codes `height: 28px` five times: use `--control-h`.
24. The `+ 0.5px` in the fillet masks becomes a named custom property; `.bri-label`'s
    `right: calc(100% + 28px)` uses a variable for the track offset; `.filmstrip` is a
    grid, so rename it.

Behaviour and names
25. Refusals on actions this branch added must show, not vanish: rules.ts "Add a rule",
    notifications.ts "Turn on", assistant.ts model cycle, and controls.ts levels (show the
    real level again when Rust refuses). Show the reason the way `frame.commit` does.
    Leave main's older `.catch(() => {})` calls alone.
26. `keyboardField` applies `user-select: text` itself so callers stop needing it.
27. `setLine` in marquee.ts measures 0 on a hidden box, so player.ts resets `linesShown` to
    force a remeasure: measure on show or with a ResizeObserver, and delete the resets.
28. Renames: `MARQUEE.pause` to `dwellFraction`, `spring(ratio…)` to `dampingRatio`,
    `START_SPAN` to `START_SPAN_INDEX`, controls.ts `latest` to a name that says it sends
    one call at a time. Named constants for calendar.ts's magic Sunday
    (`new Date(2024, 0, 7 + day)`) and the `+ 500` in `armMidnight`. Named capture groups in
    markdown.ts `INLINE`.
29. scripts: barcheck.swift's window levels 5 and 4 become `BAR_LAYER` and `FRAME_LAYER`;
    dev.sh's `usage` prints what each verb does (eval returns JSON; type maps ESC to
    Escape and DEL to Backspace).
30. wallpaper-folder.sh: write the tilde patterns as `\~` and `\~/*` and drop
    `excludeShellChecks = [ "SC2088" ]` from edgebar.nix (ShellCheck 0.11 accepts that
    form; prove the script still expands `~` and `~/Pictures`).

## Done means

- Small commits in a sensible order, each one type-checked (`pnpm exec tsc --noEmit`),
  Conventional (`refactor(edgebar): ...`, `fix(edgebar): ...`), staged by explicit path
  (never `git add -A` or `commit -a`), body ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push.
- `nix develop -c pre-commit run --all-files` passes from the repo root.
- The before and after snapshots are compared and every difference explained.
- No comment in your diff narrates; keep a comment only for a why the code cannot show.
- `~/.config/edgebar/settings.json` is absent at the end, the mode is auto, and the desktop
  picture is what it was when you started.
- Report: commits, each item done or skipped with the reason, the snapshot comparison,
  and anything you could not prove.
