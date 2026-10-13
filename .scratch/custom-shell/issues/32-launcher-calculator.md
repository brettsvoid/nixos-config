# Launcher calculator

Status: ready-for-human
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A calculator mode in the launcher, as Caelestia has (gaps list). Typing `=` first turns
the rest of the query into an expression. qalc (libqalculate, as Caelestia uses)
evaluates it, so units, currencies and bases work too: `= 5 km to mi`,
`= 0x1f to dec`.

- One row shows the result, and the expression under it. Enter copies the result to
  the clipboard.
- qalc runs once per expression, after typing pauses, and only in this mode. One run
  takes about 50 ms.
- An expression qalc cannot read shows that, rather than an empty list.

## Acceptance criteria

- [ ] `=2+2` shows 4. Enter puts 4 on the clipboard.
- [ ] Unit and base conversions work.
- [ ] Nothing runs while the launcher is in another mode.
- [ ] The apps mode's placeholder mentions the new prefix.

## Blocked by

- .scratch/custom-shell/issues/05-launcher-drawer.md

## Comments

**2026-10-13:** Built, not yet committed, and tested headless (see issue 31).

- **Results:** `=2+2` gives 4, `=-5+2` gives -3 (ASCII, through `-s 'unicode off'`),
  and `=0x1f to dec` gives 31. `=hello world` says qalc cannot work it out: qalc exits
  non-zero, though it still prints a guess. Typing quickly settles on the last query.
- **Enter:** copies the result. If the result still showing is for an older query,
  Enter works out the current one and copies that.
- **Units:** qalc gives mixed units for some conversions: `5 km to mi` is
  `3 mi + 188 yd + 2.39 in`. Its command line has no setting to turn that off.
- `libqalculate` is in `home.packages`, so `qalc` works in a terminal too. It writes
  `~/.config/qalculate/qalc.cfg` the first time it runs.
- **Left for you:** try it in the real launcher.
