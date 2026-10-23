# Brief: give edgebar the custom shell's look

You own this diff. Do not spawn subagents. Read first, in full:
`/Users/brett/.claude/skills/poteto-mode/SKILL.md` (Principles section included),
`/Users/brett/nixos-config/CLAUDE.md`, `/Users/brett/.claude/CLAUDE.md` (UK English
everywhere, no conjecture, pragmatic), `.scratch/edgebar-notch/PLAN.md`, and the custom
shell's own source for every value below: `modules/home/desktop/quickshell/theme/
Theme.qml`, `frame/FrameShape.qml`, `shaders/frame.frag`, `frame/Drawer.qml`,
`frame/FrameWindow.qml`, `bar/Bar.qml`, `bar/Workspaces.qml`, `bar/Clock.qml`,
`components/Pill.qml`, `components/Slider.qml`, `dashboard/Dashboard.qml`. The custom
shell is MIT-licensed code in this repo, but write CSS/Rust of your own, not a port.

## Why

Brett asked for edgebar to look "a bit more like" his brett-desktop shell. edgebar today
is ambxst-style: light pills hanging from a 4 px coloured frame line, black screen
corners. The custom shell is one dark frame around the screen with the bar as its top
band and drawers growing out of it. Keep edgebar's layout (workspaces left, notch centre,
CPU/controls/status/clock right) and its notch; change the look.

## Target (values from the custom shell; file:line in its source)

1. **Frame.** One opaque shape in the surface colour: 8 px left, right and bottom
   (`Settings.qml` frameThickness 8), the 32 px bar as its top band (`Theme.barHeight`),
   the hole's corners 16 px (`frameRounding`). No black corner fills. A soft shadow falls
   inward from the frame's inner edge all the way round: 12 px, black, 0.30 at the edge
   with a quadratic falloff to 0 (`frame.frag:85-91`); match it by eye with a CALayer
   shadow on a layer of its own. The native frame (`create_native_frame` in lib.rs)
   draws the whole shape; the bar window must sit ABOVE the frame window (today the frame
   is level 6 over the bar at 5; change that), and the bar's WebView paints the same 32 px
   band again so drawers join it with no seam between two windows.
2. **Colour roles** (both modes): band, frame, notch and drawers = matugen `surface`
   (palette key `base`); text and icons = `on_surface` (`text`); dim text =
   `on_surface_variant` (`subtext0`); the single accent for every active or selected state
   = `primary`; ink on an accent fill = the surface colour. Cards and tracks are tints of
   the surface toward the text, as the custom shell derives them (`Theme.qml:30-31`):
   container about 7 %, container-high about 11 %, bright 20 %. Flip the view tokens in
   `styles.css :root` (`--surface`, `--on-surface`, `--on-surface-variant`, `--primary`,
   `--on-primary`, `--surface-container`, `--surface-container-high`, `--surface-bright`)
   to these, and retire the pill-era ones (`--pill-bg` as a fill, `--track`, `--hover`,
   `--wip-*` if unused) once nothing reads them.
   Light-mode `primary` doesn't exist in the deployed palette: the matugen template
   (`modules/home/darwin/edgebar/matugen/palette.json.tmpl`) maps `rosewater` to
   `primary_container` in light. Add a `primary` key (both modes) to the template and to
   `src-tauri/palette.default.json`, and let a role name a fallback, e.g.
   `"accent": "primary|rosewater"` (first key the palette has wins), in
   `resolve_colors`, so today's palette.json keeps working until Brett rebuilds. Keep the
   ink and accent contrast checks working against the new pill colour.
3. **Bar band.** The pills become segments laid on the band: no backgrounds, fillets,
   drop shadows or detached boxes. 12 px from each end, 16 px between segments
   (`Bar.qml:18,32,36`). Hover feedback only where something is clickable, and quiet.
4. **Workspaces** (`Workspaces.qml`): 8 px dots 4 px apart; empty = surface-bright,
   occupied = on-surface-variant, active = a 24×8 `primary` capsule; width and colour
   animate over 150 ms. Keep edgebar's app icons for occupied workspaces at 16 px; the
   active one sits on a `primary`-tinted capsule.
5. **Clock** (`Clock.qml`): time 13 px bold, a 1×16 divider in surface-bright, the date
   12 px in on-surface-variant, 8 px apart.
6. **Notch.** Collapsed, its content sits on the band. Open, it is a drawer: it grows
   down out of the band, joined to it by 16 px concave fillets, with 28 px corners away
   from the band (`Theme.drawerRadius`) and 16 px padding (`drawerPadding`). Its content
   is clipped by the growing box and slides out from behind the band; no opacity fade
   (`Drawer.qml:127,159`). The controls popup and the ⌘ launcher menu become the same
   kind of drawer, hanging from the band under their buttons.
7. **Motion.** Replace the springs in `src/motion.ts` with the custom shell's Material 3
   springs (`Theme.qml:83-92`, mass 1): drawers use default spatial (damping ratio 0.8,
   stiffness 380, so Motion's `damping` = 2·0.8·√380 ≈ 31.2); small moves fast spatial
   (0.6, 800); colour and opacity default effects (1, 1600). Keep the reduced set: don't
   add a spring nobody uses.
8. **Rail and controls in the open notch.** Rail buttons full-round; the active one is a
   `primary` fill with on-primary icon; hover surface-container-high (`Pill.qml`,
   `Dashboard.qml:79-90`). Existing toggles, chips, sliders and metric bars use the
   container tokens and `primary` fills (`Slider.qml`: 6 px track, 18 px handle).
   Placeholders (`.ph`, `.wip`) only need to stay legible; workers are replacing them.

Delete what the new look makes dead (the corner layer, `frameCorner` if nothing else uses
it, pill fillet CSS the notch drawer doesn't reuse, `topOffsetPx` if the band now covers
the dead row: verify, don't assume). Update `src-tauri/config.default.json`,
`modules/home/darwin/edgebar.nix` (if it overrides any geometry you rename) and
`docs/bar-spec.md` §3 so the spec describes the new look.

## How you work, and the live app

Edit the main working tree on branch `edgebar-notch` (no worktree, no branch switch).
Brett's `pnpm tauri dev` runs this tree in herdr pane `w1:p4`: Vite hot-reloads the
WebView, and saving any file under `src-tauri/` rebuilds and relaunches the app. Don't
start another `tauri dev`, don't run cargo against `src-tauri/target` (lock clash); for a
quick type check use `CARGO_TARGET_DIR=/Users/brett/.cache/edgebar-agent-target cargo
check`. Read build output with `herdr pane read w1:p4 --source recent --lines 60`.

`apps/edgebar/scripts/dev.sh eval '<js>'` and `dev.sh snap <abs.png>` drive and
snapshot the live bar (read the script and devtools.rs first). The snapshot composes
each window's own pixels; it can't show a colour mismatch between the two windows, so
also `dev.sh eval` the band's computed colour and compare it with the frame's fill hex.

Snapshots go under
`/private/tmp/claude-501/-Users-brett-nixos-config/d8cb2a47-141a-461f-86e4-14bdf688cfa3/scratchpad/restyle/`.
Brett's machine is in `auto` appearance with scheme-monochrome; check both light and dark
by calling `set_appearance` through eval, then put it back to `auto`.

## Proof (all in your report)

1. Snapshots of: bar idle (dark), bar idle (light), notch open on each view, the
   controls drawer, the launcher drawer. Open each with your Read tool and describe it
   against targets 1-8, naming any target you missed.
2. The band's computed colour equals the frame's fill in both modes (eval output).
3. `tsc` exits 0, the app relaunched clean in the pane, `nix develop -c pre-commit run
   --all-files` passes.
4. A grep showing no CSS or TS still reads a token you retired.

Commit in small, ordered steps on `edgebar-notch` (Conventional Commits,
`feat(edgebar): …`, short bodies, each ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Don't push. Leave the app in
`auto` with the notch closed.

Comments: only a non-obvious why, written clean (no long dashes). UK English.

## Report (under 60 lines)

What changed per target, what you deleted, anything you chose differently from this
brief and why, the snapshot paths, proof 1-4.
