# edgebar: fill the notch, add settings, take the custom shell's look

Status: done (2026-10-24), in review. The UI units ran one at a time on the live tree, not in worktrees (decisions.tsv, 23:52:48Z).

The ask: fill every placeholder in edgebar's notch with real UI, add a settings view with
what edgebar needs to be set up, and make the bar look a bit more like the brett-desktop
custom shell (`modules/home/desktop/quickshell`). Decisions that need Brett were delegated
("go with what you suggest"); each is logged in `decisions.tsv` with its reason.

## Done means

1. No `.wip` or `.ph` element is left in `apps/edgebar` (checked by a grep and by
   `scripts/dev.sh eval` on the live bar).
2. Every rail tab opens a working view: Dashboard, Wallpapers, Performance, Assistant,
   Settings.
3. Each widget shows live data from its macOS source, or says plainly why it can't
   (a permission it lacks, a source macOS doesn't offer).
4. The live bar, snapshotted with `scripts/dev.sh snap`, shows the custom shell's
   signature: one frame in the surface colour (8 px sides and bottom, the bar as the
   32 px top band, 16 px inner corners, a soft inward shadow), and the notch opening as a
   drawer joined to the band by 16 px fillets, 28 px corners away from it.
5. `tsc`, `cargo check` and `nix develop -c pre-commit run --all-files` pass.

## Verification lever

No process on this Mac can screen-capture (TCC rejects nix kitty-bin's signature; herdr
has no grant). So the app snapshots itself: a debug-only `~/.cache/edgebar/dev.sock`
(`src-tauri/src/devtools.rs`, client `scripts/dev.sh`) runs JS in the bar's WebView and
writes a PNG composed from the WebView snapshot and the native frame's layers. The live
`pnpm tauri dev` in herdr pane `w1:p4` rebuilds on every save; read its output with
`herdr pane read w1:p4 --source recent --lines 60`.

Limit: the composite is built from each window's own pixels, so a colour mismatch
between the native frame and the WebView would only show on a real screen capture.

## The look (from the custom shell's source)

| Trait | Custom shell | edgebar after |
|---|---|---|
| Frame | `base` fill, 8 px sides/bottom, bar = 32 px top band, hole radius 16, inward shadow 12 px 0.3 black | same; native frame draws the ring, the WebView repaints the top band so drawers join it seamlessly |
| Bar | content on the band, no pill backgrounds | pills become segments on the band |
| Workspaces | 8 px dots, active 24×8 `primary` pill, occupied `subtext`, empty `base`+20% `text` | same; app icons kept for occupied workspaces |
| Drawers | radius 28 away from frame, 16 px fillets, 16 px padding, spring ζ 0.8 k 380, content clipped not faded | notch panel and the two popups become drawers |
| Cards and controls | `surfaceContainer` cards, full-round pills, `primary` for every active state | same |
| Colour | `base`=surface, `text`=on_surface, accent `primary` | role map remapped; light-mode `primary` added to the matugen template with a fallback |

## Waves

- Wave 0 (serial): the dev socket; baseline snapshots; a behaviour-preserving split of
  the notch into a view registry with one TS and one CSS file per view, typed IPC, and
  the new colour tokens wired to today's values.
- Wave 1: the restyle on the main tree (live), and the feature backends plus views in
  worktrees, each owning its own files.
- Wave 2 (serial): merge each feature into the main tree and verify it live.
