# Record that the Quickshell bar and edgebar now go their own ways

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

`docs/bar-spec.md` makes edgebar (macOS) the reference and asks the Quickshell bar to
match ambxst's look. That no longer holds: the Quickshell shell now follows a
Caelestia-style look of its own, and edgebar keeps its current spec. Update the docs so
nobody (human or agent) keeps chasing parity.

Say clearly that the split is deliberate and may be undone later. Keep edgebar's spec
intact as edgebar's own. Point Quickshell readers at the custom-shell PRD. Update the
parity items in `docs/refactor-plan.md` that track Quickshell catching up.

## Acceptance criteria

- [ ] `docs/bar-spec.md` states that it now covers edgebar only, why, and that the bars
      may be reunited later.
- [ ] The Quickshell "has to catch up" wording and parity checklist entries are removed
      or marked as no longer applying.
- [ ] `docs/refactor-plan.md` no longer lists Quickshell visual parity as pending work.
- [ ] No other doc or comment still tells the Quickshell bar to follow edgebar (search
      for "parity" and "bar-spec").

## Blocked by

None - can start immediately.

## Comments

**2026-10-09:** Done.
- `docs/bar-spec.md` is retitled "Bar spec — edgebar". A note at the top says it covers
  edgebar only since 2026-10-09, why (the custom shell's Caelestia-style frame doesn't fit
  the ambxst pill language), that the split may be undone, and points at this PRD.
- §1 and §2 are kept as a record of both bars at the split. §3 to §5 are edgebar's own:
  the QML-only instructions are removed (Hyprland `exclusiveZone`, the Lucide-in-QML
  note, `mask: Region`, the quickshell side of §4), and the QML fallback column is marked
  as no longer applying. The checklist keeps the shared and edgebar items, renumbered
  1–6; the quickshell items 4–12 and 16 are gone.
- `docs/refactor-plan.md`: the parity deferral is struck through and marked dropped,
  Phase 5 is retitled with a note, and the suggested order, the companion-doc line, the
  bar-tokens item and Q-4 no longer point the QML bar at edgebar. The 2026-07-02 audit
  history is left as written.
- README tree entry, `apps/edgebar/README.md` and the `Theme.qml` comment now call it
  edgebar's spec.
- Search for "parity", "bar-spec" and "catch up" outside `.scratch`: only history and
  the record sections remain. Nothing in `modules/home/desktop/quickshell` or
  `custom-shell.nix` mentions edgebar now.
