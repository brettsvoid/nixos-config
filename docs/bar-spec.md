# Bar spec — edgebar ⇄ quickshell parity

One normative design language for both status bars:

- **edgebar** — macOS Tauri overlay (`apps/edgebar`)
- **quickshell** — Wayland/QML bar (`modules/home/desktop/quickshell`)

Both target the ambxst look (screen-edge frame + attached pills). Values below are
pulled from the current code, chosen from whichever bar is further along — usually
edgebar, which already encodes the frame language and a full token scale. Where the
two disagree today, this doc is the tie-breaker.

Status legend in the checklist: edgebar is the reference implementation; quickshell is
the one that has to catch up (it currently has ~3 segments to edgebar's ~8).

---

## 1. Current state

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
| Systray / media | not implemented (roadmapped last) | not implemented | ✓ |

`~` = format agrees but mechanism/values differ.

---

## 2. Divergences to reconcile

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

## 3. Normative spec

### 3.1 Geometry

| Token | Value | Notes |
|---|---|---|
| `bar.height` | **32** | interactive band; WM top reservation = height + gap (AeroSpace `outerTop = 32+10`; Hyprland `exclusiveZone = 32 + gaps_out`) |
| `bar.windowHeight` | 64 | render surface incl. transparent overshoot for shadow/fillet |
| `frame.lineThickness` | **4** | screen-edge frame line (= ambxst `frameThickness`) |
| `frame.innerRadius` | **20** | frame inner corner radius |
| `pill.radius` | **16** | pill bottom corners |
| `pill.concave` | **16** | fillet radius — invariant `= bar.height / 2` |
| `pill.padX` | 12 | horizontal pill padding (`space-6`) |
| `pill.gap` | 4 | sibling pill gap (`space-2`) |

Corner pills (workspaces top-left, clock top-right) sit square against the frame
corner with a fillet on the outer bottom edge only. Detached pills (e.g. controls
cog): radius 14, height `bar.height − 2`, top-offset +2.

### 3.2 Colour roles

Single vocabulary, both modes. matugen source is normative — dropping edgebar's
Catppuccin aliasing and quickshell's raw-token dump.

| Role | matugen (dark) | matugen (light) | Use |
|---|---|---|---|
| `base` | `surface` | `on_surface` | frame-adjacent ink; text on pills |
| `pillBg` | `primary` | `primary_container` | pill/segment background |
| `text` | `on_surface` | `on_surface` | primary text |
| `subtext` | `on_surface_variant` | `on_surface_variant` | secondary text |
| `accent` | `tertiary` | `tertiary` | active-workspace ring, selection |
| `occupied` | `secondary` | `secondary` | occupied-workspace mark |
| `empty` | `outline` | `outline` | empty-workspace mark |
| `batteryCharging` | `#40a02b` | `#40a02b` | fixed semantic green |
| `batteryLow` | `#d20f39` | `#d20f39` | fixed semantic red |
| `vpn` | `#179299` | `#179299` | fixed teal |
| `warn` | `#df8e1d` | `#df8e1d` | no-internet |
| `frameLine` | = `pillBg` | = `pillBg` | frame ring |
| `frameCorner` | `#000000` | `#000000` | corner fills |

Derived marks (alpha of `base` over `pillBg`): `separator 30%`, `handle 45%`,
`track 18%`, `hover 12%`, `wsEmpty 28%`, `wsOccupied 55%`.
Shadows: pill `0 3px 6px rgba(0,0,0,.4)`, popup `0 6px 16px rgba(0,0,0,.35)`.

Default scheme **`scheme-tonal-spot`**; appearance **auto**; fallback palette =
Catppuccin Latte/Mocha (`palette.default.json`).

### 3.3 Scales

- **Spacing** (2px grid): `s1..s9 = 2,4,6,8,10,12,14,16,18`.
- **Radius**: `sm 8, md 12, lg 14, pill 16`.
- **Type** (px): `2xs 10, xs 11, sm 12, md 13 (base), lg 14, xl 16, 2xl 18, 3xl 30`.
  Font **FiraCode Nerd Font**, mono variant for data labels (SSID). Numerics
  `tabular-nums`; time/percent bold (700).
- **Dim**: `dim .75, dimMore .5, dimIcon .8`.
- **Icons**: Lucide geometry (stroke 2, round caps), 1em in a 1.2em cell at `2xl`.
  QML renders the same Lucide paths via `Shape`/SVG — not Font Awesome codepoints —
  so glyph shapes match.

### 3.4 Segments (left → right)

1. **workspaces** (corner, left) — launcher button + dynamic dots. Empty 8px circle
   `wsEmpty`; occupied circle `wsOccupied` or 22px app-icon cell where the WM exposes
   icons; active = `base` dot + ring `1px pillBg / 3px accent` (or `accent@22%`
   backplate + 2px ring when icon).
2. **notch** (center, expandable) — compact 26×4 handle; expanded 250×250 = big clock
   (3xl) + metrics rows; theme view 704×256.
3. **controls** (detached cog) — dropdown ≥200px, sliders volume/mic/brightness,
   track 5px `track`, thumb 14px `base`.
4. **status** — Wi-Fi arc icon (dBm bounds −82/−72/−60, ±3 hysteresis) + SSID (`2xs`
   mono) · battery icon + `%` (bold). Battery: charging bolt; ≤20 low; ≤60 medium;
   else full. No mid-yellow.
5. **clock** (corner, right) — `HH:mm` bold · hairline 1×14 `separator` · `ddd, MMM d`
   (`sm`, dim). Minute-aligned tick.

### 3.5 Motion

| Name | Spring (stiffness/damping) | QML fallback |
|---|---|---|
| reveal (bar in) | 420/26, stagger 50ms | 300ms `OutCubic` |
| hide | 520/34, stagger 30ms | 200ms `InCubic` |
| panelOpen | 280/26 | 350ms `OutCubic` |
| panelClose | 320/30 | 280ms `OutCubic` |
| popup | 300/26, y from −8 | 300ms `OutCubic` |
| fadeIn / fadeOut | 250ms (delay 80) / 120ms | same |
| workspace dot | 150ms `cubic-bezier(0.2,0.8,0.2,1)` | 150ms `OutQuad` (already matches) |

### 3.6 Interaction / click-through

- Idle: only pill rects are interactive; transparent overshoot passes clicks through.
  QML `mask: Region` composed of the segment items, not the whole strip.
- Panel open: whole bar window interactive; outside-click / pointer-leave collapses
  all panels; only a panel header toggles (content clicks don't collapse).
- Workspace dot click focuses that workspace. Bar never takes keyboard focus.

---

## 4. Single source of truth

Three files, one owner each; both bars are pure consumers.

1. **`modules/shared/bar/tokens.json`** — static design tokens (§3.1/3.3/3.5:
   geometry, spacing, radii, type, motion, dim). Distributed via Nix like the existing
   `bar-geometry.nix`: promote to `flake.lib.barTokens = lib.importJSON ./tokens.json`.
   - edgebar: merge `barTokens` into the rendered `~/.config/edgebar/config.json`
     (`edgebar.nix` already renders it; `main.ts applyConfig()` already maps config →
     CSS vars).
   - quickshell: `custom-shell.nix` writes `tokens.json` into the config dir;
     `Theme.qml` (already using `FileView` + `JSON.parse` for colours) replaces
     hardcoded `barHeight/roundness/fontSize` with lookups.
   - Invariants (`concave = barHeight/2`, WM top reservation) stay computed in Nix at
     render time, as `edgebar.nix` already does.

2. **`modules/shared/bar/palette.json.tmpl`** — one matugen template replacing the two
   divergent ones. Emits **both** `dark` and `light` blocks keyed by the §3.2 role
   names. Both platform matugen configs point `input_path` here; output paths stay
   local (`~/.config/edgebar/palette.json`, quickshell's renamed to `palette.json`).
   Rust's `Colors` struct and `Theme.qml`'s `c(token, fallback)` read the same keys, so
   drift becomes a parse failure, not silent skew. Scheme default written from one Nix
   constant into `generate-edgebar-theme`, `generate-theme`, and `ambxst.nix`.

3. **Live-reload contract** — keep each platform's transport (edgebar `theme.sock`,
   quickshell `FileView.watchChanges`). The file *shape* is the contract, not the wire.

Optional guard: a `nix flake check` that asserts the Rust `Colors` field list ==
template keys == the role list in §3.2.

---

## 5. Parity checklist

**Shared (unblocks both)**

1. Create `modules/shared/bar/tokens.json` + `palette.json.tmpl` with §3 values; wire `flake.lib.barTokens`.
2. Rename edgebar palette keys Catppuccin→roles (`rosewater→pillBg`, `blue→accent`, `peach→occupied`, `surface1/overlay0→empty`) across `palette.json.tmpl`, `config.default.json`, `lib.rs Colors`, `palette.default.json`.
3. Pin the shared scheme default (`scheme-tonal-spot`) across `generate-edgebar-theme`, `generate-theme`, `ambxst.nix`.

**quickshell (long tail)**

4. Read `tokens.json` in `Theme.qml`; `barHeight 36→32`, `fontSize 14→13`; align Hyprland `exclusiveZone`.
5. Two-mode palette + mode field; consume role names.
6. Rebuild chrome to the attached-pill language: 4px frame line, 20 inner radius (QML `Shape`), corner pills, concave fillets, `pillBg` surface with `base` ink (polarity flip), pill/popup shadows.
7. Workspaces: dynamic list (drop fixed 10), circle dots + accent-ring active, `base`-tint empty/occupied, app icons from toplevels, launcher button. *(Note: the current `hasWindows` logic is broken — see refactor plan N-1.)*
8. Clock: minute-aligned `SystemClock`; port the expandable notch (big clock + metrics).
9. Status pill: NetworkManager Wi-Fi (same RSSI bounds/hysteresis, Lucide arc), battery to Lucide icons + ≤20/≤60 thresholds, drop `batteryMid`.
10. Controls popup: PipeWire volume/mic + brightnessctl sliders (60/60/40ms debounce).
11. Click-through: per-segment `mask: Region`; full-strip while a panel is open.
12. Reveal/hide + panel animations (§3.5 fallback column).

**edgebar (small)**

13. Consume `tokens` from shared config (delete duplicated `styles.css :root` defaults or keep as fallback only).
14. Adopt renamed roles end-to-end; move hardcoded `warn` into the palette template.
15. Later, per roadmap: front-app title, systray, media — spec'd when one bar grows them.
