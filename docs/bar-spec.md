# Bar spec — edgebar

The design language of **edgebar**, the macOS Tauri overlay bar (`apps/edgebar`): one
frame in the surface colour, with the bar as its top band and drawers that grow out of
it, after the custom shell (§3).

> **Edgebar only, since 2026-10-09.** This spec used to bind two bars, edgebar and the
> Wayland/QML bar in `modules/home/desktop/quickshell`, with the QML bar catching up to
> edgebar. That bar is now being rebuilt as a shell of its own with a Caelestia-style
> look (a frame whose drawers grow out of it), which the ambxst pill language doesn't
> fit. So the two bars go their own ways on purpose. This may be undone later; until
> then nothing here is work for the Quickshell shell, and that shell's design lives in
> `.scratch/custom-shell/PRD.md`.
>
> §1 and §2 still describe both bars, as they stood when they split, as a record for a
> possible reunion. §3 onwards is edgebar's own spec.

---

## 1. State when the bars split

Snapshot from before 2026-10-09. The quickshell column is the old QML bar, which the
custom shell replaces.

| Concept | edgebar (macOS) | quickshell (Wayland) | Match |
|---|---|---|:---:|
| Band height | 32 (`bar-geometry.nix`, shared with AeroSpace `outerTop`) | 36 (`Theme.barHeight`) | ✗ |
| Edge attachment | Pills hang from screen edge, 16px concave fillets under a 4px frame line | Segments float 4px inside every edge, no frame | ✗ |
| Surface polarity | Pills = light `pillBg`, dark ink | Segments = dark `base`, light text | ✗ |
| Blur | none (opaque + drop-shadow) | none (opaque + `MultiEffect` shadow) | ~ |
| Workspaces | AeroSpace, event-driven, dynamic list, app-icon dots, accent ring on active | Hyprland IPC, fixed 10, width-morphing capsule, no icons | ✗ |
| Clock | `HH:mm` + hairline + date, minute-aligned tick | `hh:mm` + separator + date, 1s timer always on | ~ |
| Battery | `pmset` 60s poll, Lucide SVG, thresholds ≤20/≤60 | UPower events, Nerd Font glyph, thresholds >25/>50/>75 | ✗ |
| Network / Wi-Fi | Event-driven RSSI arc icon, SSID, VPN, no-internet warn | **not implemented** | ✗ |
| Volume/brightness/mic | Controls dropdown, 3 sliders | **not implemented** | ✗ |
| Metrics (cpu/mem/disk) | Notch panel, sampled 2s while open | **not implemented** | ✗ |
| CPU graph | Bar pill: 108×1px stacked system/user histogram (2s, always on) + top process name/pid (6s); also feeds the notch's CPU metric | **not implemented** | ✗ |
| Theming source | matugen → `~/.config/edgebar/palette.json` (dark+light), socket reload, light/dark/auto | matugen → `~/.cache/qs-theme/colors.json` (single mode), file-watch | ✗ |
| Default scheme | `scheme-tonal-spot`, appearance auto | `scheme-neutral`, mode pinned light | ✗ |
| Fonts | FiraCode Nerd Font, base 13, Lucide SVG icons | FiraCode Nerd Font, base 14, Nerd Font glyph icons | ~ |
| Click-through | Per-pill interactive rects, cursor-tracked | Whole-strip mask | ✗ |
| Fullscreen apps | Bar + frame order out while a window covers that display (500ms window-list poll) | layer-shell `Top`, left to the compositor | ~ |
| Notch content | Priority slot: OSD flash > per-workspace rule > audible app (CoreAudio + AppleScript metadata for Spotify/Music) > idle | **not implemented** (MPRIS is available, so the media tier is nearly free) | ✗ |
| Systray | not implemented (roadmapped last) | not implemented | ✓ |

`~` = format agrees but mechanism/values differ.

---

## 2. Divergences (no longer being reconciled)

These were the gaps to close for parity. They are kept as a record only; since the
split, none of them is planned work.

1. **Band height** 32 vs 36.
2. **Edge attachment** — attached-with-frame (edgebar) vs floating (quickshell). Biggest visual gap; the ambxst frame (`ambxst.nix frameThickness=4`) only exists on macOS today.
3. **Surface polarity** — light pills vs dark segments.
4. **Workspace morphology** — ring'd circle + app icons + dynamic list vs width-morphing capsule + fixed 10.
5. **Colour-role vocabulary** — `pillBg/accent/occupied/empty` vs `barBg/wsActive/wsOccupied/wsEmpty`; edgebar's palette keys are Catppuccin aliases (`rosewater` actually means primary), quickshell's are raw Material tokens.
6. **matugen mapping** — accent = `tertiary` vs `primary`; battery colours hardcoded hex vs matugen `green/yellow/error`.
7. **Scheme + mode** — `tonal-spot`/auto vs `neutral`/light; two-mode palette vs single mode.
8. **Theme file** — `~/.config/edgebar/palette.json` (+socket) vs `~/.cache/qs-theme/colors.json` (+file-watch).
9. **Typography** — 13 vs 14 base; Lucide SVG vs Nerd Font glyphs; different battery icon thresholds.
10. **Clock tick** — minute-aligned single wake vs always-on 1s timer.
11. **Click-through** — per-pill vs whole-strip.
12. **Feature gap** — quickshell lacks network, controls, launcher, notch/metrics, theme UI, app icons.
13. **Token discipline** — edgebar has named spacing/motion scales; quickshell hardcodes literals.

---

## 3. Normative spec (edgebar)

Since 2026-10-24 edgebar takes the custom shell's look (`modules/home/desktop/quickshell`):
one frame in the surface colour, with the bar as its top band and drawers that grow out
of it. The values below come from that shell's source; the file named in each row says
where.

### 3.1 Geometry

| Token | Value | Notes |
|---|---|---|
| `geometry.barHeight` | **32** | the band: the frame's top edge, and the strip AeroSpace keeps clear (`outerTop = 32 + 10`); Nix sets it from `flake.lib.barGeometry` (`Theme.barHeight`) |
| `geometry.frameThickness` | **8** | the frame's sides and bottom (`Settings.qml` `appearance.frameThickness`) |
| `geometry.frameRadius` | **16** | corners of the hole inside the frame (`Theme.frameRounding`) |
| `geometry.windowHeight` | 64 | the bar window while no drawer is open; an open drawer grows it to fit |
| `--bar-pad` | 12 | each end of the band to its first segment (`Theme.barPadding`) |
| `--seg-gap` | 16 | between segments (`Bar.qml`, `Theme.spacingLarge`) |
| `--fillet` | 16 | the curve where a drawer meets the band (`Theme.frameFillet`) |
| `--radius-drawer` | 28 | a drawer's corners away from the band (`Theme.drawerRadius`) |
| `--drawer-pad` | 16 | a drawer's padding (`Theme.drawerPadding`) |
| shadow | 12 | inward from the frame and out from each drawer: black, 0.3 at the edge, fading quadratically to 0 (`frame.frag`) |

The frame is one opaque shape in `surface`: the band along the top, `frameThickness`
down the sides and along the bottom, round a hole with `frameRadius` corners. The native
frame window (level 4) draws it, with its shadow as gradients that follow the falloff
exactly. The bar window (level 5) sits above it and paints the band again, so the
drawers join the band with no seam between two windows. The drawers' CSS shadow,
`drop-shadow(0 0 6.5px rgb(0 0 0 / 0.6))`, was measured in the dev snapshot to match the
frame's within one 8-bit step. The display's top device row, which it does not show, is
band colour in both windows, so it hides nothing.

### 3.2 Colour roles

| Role | Palette key | matugen | Use |
|---|---|---|---|
| `surface` | `base` | `surface` | the band, the frame, the notch and every drawer; ink on an accent fill |
| `text` | `text` | `on_surface` | text and icons |
| `subtext` | `subtext0` | `on_surface_variant` | dim text |
| `accent` | `primary\|rosewater` | `primary` | every active or selected state |
| `batteryCharging` | `#40a02b` | | fixed semantic green |
| `batteryLow` | `#d20f39` | | fixed semantic red |
| `vpn` | `#179299` | | fixed teal |
| `warn` | `#df8e1d` (CSS only) | | no internet, a rail alert |

The same keys serve both modes. `a|b` names fallbacks, and the first key the palette has
wins: `rosewater` serves palettes rendered before the template had `primary`.

The view tokens in `styles.css :root` are derived from these: `--surface`,
`--on-surface` (`text`), `--on-surface-variant` (`subtext`), `--primary` (`accent`),
`--on-primary` (`surface`). Cards, tracks and quiet marks are `surface` tinted toward
`text`, as the custom shell derives them (`Theme.qml`): `--surface-container` 7 %,
`--surface-container-high` 11 %, `--surface-bright` 20 %.

`text` has to clear 4.5:1 on `surface` (WCAG AA) and `accent` 3:1; otherwise the palette
colour with the most contrast replaces it. The theme view's Ink control pins `text` per
scheme.

Default scheme **`scheme-tonal-spot`**; appearance **auto**; fallback palette =
Catppuccin Latte/Mocha (`palette.default.json`).

### 3.3 Scales

- **Spacing** (2px grid): `s1..s9 = 2,4,6,8,10,12,14,16,18`.
- **Radius**: `sm 8, md 12, card 16, drawer 28`. Buttons, chips and tabs are full-round.
- **Type** (px): `2xs 10, xs 11, sm 12, md 13 (base), lg 14, xl 16, 2xl 18, 3xl 30`.
  Font **FiraCode Nerd Font**, mono variant for data labels (SSID). Numerics
  `tabular-nums`; time/percent bold (700).
- **Dim**: `dim .75, dimMore .5, dimIcon .8`.
- **Icons**: Lucide geometry (stroke 2, round caps), 1em in a 1.2em cell at `2xl`.

### 3.4 Segments (left to right)

Segments are content laid on the band: no background, fillet, shadow or box of their
own.

1. **workspaces** (`Workspaces.qml`): the ⌘ launcher button, then the dots. 8px dots
   4px apart: empty `surface-bright`, occupied `subtext`, active a 24×8 `accent`
   capsule. Width and colour ease over 150ms (OutQuad). An occupied workspace whose app
   the WM names shows that app's icon at 16px; the active one sits on a 32×20 capsule of
   `accent` at 25 % over `surface`.
2. **cpu**: the hungriest process's name (`subtext`) over the total percentage and a
   108×14 stacked system/user graph.
3. **notch** (centre): collapsed, a row on the band at one of two fixed widths, 200
   idle (the 26×4 handle in `surface-bright`), 320 with an item. An item is a 20px
   art/glyph cell, an `xs`/600 headline over a `3xs` `subtext` subline, and a 2px
   progress hairline. Text that overflows marquees (dwell, travel, dwell, back) rather
   than widening the row: a width that tracked content made the whole bar twitch on
   every song change. A playable source becomes a media pill filling the row (album art
   under a scrim, white transport). Open, it is a drawer (§3.5).
4. **controls**: a button whose drawer holds the volume, mic and brightness sliders
   (`Slider.qml`): a 6px `surface-container-high` track filled in `accent` up to an
   18px `accent` handle.
5. **status**: Wi-Fi arc icon (dBm bounds −82/−72/−60, ±3 hysteresis) + SSID (`2xs`
   mono) · battery icon + `%` (bold). Battery: charging bolt; ≤20 low; ≤60 medium;
   else full.
6. **clock** (`Clock.qml`): `HH:mm` 13px bold, a 1×16 `surface-bright` divider, then
   `ddd, MMM d` at 12px in `subtext`, 8px apart. Minute-aligned tick.

Hover feedback only where something is clickable, and quiet: a `surface-container`
plate behind ⌘, the controls button, the notch row and the menu items; a lighter dot,
or a plate behind an app icon, on the workspaces.

### 3.5 Drawers

The notch, the controls and the ⌘ menu open as drawers (`frame/Drawer.qml`). A drawer
is a `surface` box that grows down out from behind the band, joined to it by fillets
that grow to 16px as it opens, with 28px corners away from the band and 16px padding.
Its content rides the box's lower edge, so it slides out from behind the band, clipped
by the growing box, never faded.

- **notch**: centred under the row. The rail sits beside the view's body. A view's
  `size` is its own area; the shell adds the padding and the 56px rail. Rail buttons
  (`Pill.qml`, `Dashboard.qml` tabs) are 48px and full-round: `surface-container` at
  rest, `surface-container-high` on hover, `accent` with `surface` ink when active.
- **controls**: centred under its button.
- **⌘ menu**: runs on into the frame's corner, as a drawer with `align: "start"` does:
  square against the frame's side with a fillet into it, and clipped at the frame's
  inner edge so it casts no shadow on the frame.

### 3.6 Motion

The custom shell's Material 3 springs (`Theme.qml`), mass 1; Motion takes the damping
coefficient `2 × ratio × √stiffness`.

| Spring | Ratio / stiffness | Use |
|---|---|---|
| default spatial | 0.8 / 380 | drawers opening, closing and resizing |
| fast spatial | 0.6 / 800 | small moves: the notch row's width |
| default effects | 1 / 1600 | colour and opacity: the notch content's crossfade |

Workspace marks ease over 150ms in CSS. There is no reveal: the band is there from the
start, as the native frame draws it.

### 3.7 Interaction / click-through

- Idle: only the segments' rects are interactive; the rest of the bar window passes
  clicks through.
- A drawer open: the whole bar window is interactive. A click outside the drawer's
  segment, or the pointer leaving the window, closes it. Only its toggle (the notch
  row, ⌘, the controls button) opens and closes it, so clicks inside it never do.
- A workspace click focuses that workspace. The bar never takes keyboard focus.

---

## 4. Single source of truth

Three files, one owner each; edgebar is a pure consumer. (This section was written for
both bars to share; since the split it is edgebar's alone.)

1. **`modules/shared/bar/tokens.json`** — static design tokens (§3.1/3.3/3.5:
   geometry, spacing, radii, type, motion, dim). Distributed via Nix like the existing
   `bar-geometry.nix`: promote to `flake.lib.barTokens = lib.importJSON ./tokens.json`,
   and merge it into the rendered `~/.config/edgebar/config.json` (`edgebar.nix`
   already renders it; `main.ts applyConfig()` already maps config → CSS vars).
   The WM top reservation stays computed in Nix at render time, as `edgebar.nix`
   already does.

2. **`modules/shared/bar/palette.json.tmpl`** — the matugen template. Emits **both**
   `dark` and `light` blocks keyed by the §3.2 role names, written to
   `~/.config/edgebar/palette.json`. Rust's `Colors` struct reads the same keys, so
   drift becomes a parse failure, not silent skew. Scheme default written from one Nix
   constant into `generate-edgebar-theme`.

3. **Live-reload contract** — edgebar's `theme.sock`. The file *shape* is the
   contract, not the wire.

Optional guard: a `nix flake check` that asserts the Rust `Colors` field list ==
template keys == the role list in §3.2.

---

## 5. Checklist (edgebar)

The quickshell items that used to be here (catching the QML bar up to edgebar) were
dropped at the split; the Quickshell shell's own work is in `.scratch/custom-shell/`.

1. Create `modules/shared/bar/tokens.json` + `palette.json.tmpl` with §3 values; wire `flake.lib.barTokens`.
2. Rename edgebar palette keys Catppuccin→roles (`base→surface`, `subtext0→subtext`, `primary→accent`) across `palette.json.tmpl`, `config.default.json`, `lib.rs Colors`, `palette.default.json`. The roles themselves are already §3.2's.
3. Pin the scheme default (`scheme-tonal-spot`) in `generate-edgebar-theme` from one Nix constant.
4. Consume `tokens` from shared config (delete duplicated `styles.css :root` defaults or keep as fallback only).
5. Adopt renamed roles end-to-end; move hardcoded `warn` into the palette template.
6. Later, per roadmap: systray.
