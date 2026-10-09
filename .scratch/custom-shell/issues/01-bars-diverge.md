# Record that the Quickshell bar and edgebar now go their own ways

Status: ready-for-agent
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
