# Brief: split the notch into a view registry (behaviour-preserving)

You own this diff. Do not spawn subagents. Read first, in full:
`/Users/brett/.claude/skills/poteto-mode/SKILL.md` (Principles section included),
`/Users/brett/nixos-config/CLAUDE.md`, `/Users/brett/.claude/CLAUDE.md` (UK English
everywhere, no conjecture, pragmatic), and `.scratch/edgebar-notch/PLAN.md`.

## Why

The notch's three views, all their markup (index.html), logic (one 1500-line closure
in src/main.ts) and CSS (one 1400-line styles.css) share three files. Six feature
workers are about to fill its placeholders in parallel. Each needs files of its own.
This change moves code; it must not change one pixel or one behaviour.

## Target shape

The contract is already written; code against it, do not change it without saying why
in your report:
- `apps/edgebar/src/ipc.ts`: every command and event with payload types; `call()` and
  `on()` are typed wrappers. It also lists commands that don't exist yet (media_next,
  toggles, …); that is intended.
- `apps/edgebar/src/notch/view.ts`: `NotchView`, `ViewHandle`, `ViewContext`.

Build:
1. `src/notch/views.ts`: the registry, an array of `NotchView` in rail order:
   dashboard, wallpapers, performance, then the two rail buttons that have no view yet
   (Assistant, Settings) kept exactly as today (`.wip`, not clickable). The rail is
   generated from this array; today's hand-written rail markup goes.
2. One module per view, each owning its DOM (moved from index.html into a template
   string or DOM building in TS), its state, its listeners and its own CSS file imported
   from the module: `src/notch/wallpapers.ts` + `wallpapers.css`,
   `src/notch/performance.ts` + `performance.css`, and the dashboard as a folder:
   `src/notch/dashboard/index.ts` (the four-column grid and nothing else) plus one
   module per widget slot: `player.ts`, `toggles.ts`, `calendar.ts`,
   `notifications.ts`, `controls.ts`, each with its own `.css`. A widget has the shape
   `(root: HTMLElement, ctx: ViewContext) => ViewHandle`. Today every widget module just
   renders its current placeholder (`.ph` / `.wip` markup and classes unchanged).
3. `src/motion.ts`: SPRING, FADE, STAGGER moved out of main.ts, so views import them.
4. The notch shell (open/close, rail, view switching, window height, metrics health dot
   via `setAlert`) stays in main.ts or moves to `src/notch/shell.ts`, your call; say
   which and why.
5. main.ts and every new module use `call`/`on` from ipc.ts instead of raw
   `invoke`/`listen`, and import the payload types from there. Delete the duplicated
   interfaces from main.ts.
6. Colour tokens for the views. Add these to `styles.css :root`, mapped so every
   computed colour stays what it is today, and use them (not --base/--pill-bg/--track)
   in the CSS you move:
   - `--surface: var(--pill-bg)` (what the notch is painted with)
   - `--on-surface: var(--base)` (text and icons on it)
   - `--on-surface-variant: var(--base)` (dim text; today dimming is opacity, keep it)
   - `--primary: var(--accent)`, `--on-primary: var(--pill-bg)`
   - `--surface-container: var(--track)`, `--surface-container-high: var(--hover)`
   - `--surface-bright: var(--ws-empty)`
   - `--radius-card: 16px`, `--radius-drawer: var(--pill-radius)`
   A later restyle will flip these mappings in one place.

Leave the bar's own pills (workspaces, CPU, controls popup, launcher, status, clock) in
main.ts / styles.css / index.html as they are.

## How you work, and the live app

Edit the main working tree on branch `edgebar-notch` (no worktree, no branch switch).
Brett's `pnpm tauri dev` runs this tree in herdr pane `w1:p4` with Vite HMR, so the live
bar reloads as you save. Don't start another `tauri dev`, don't run cargo in
`src-tauri` (lock clash). Read build output with
`herdr pane read w1:p4 --source recent --lines 60`.

`apps/edgebar/scripts/dev.sh` drives the live bar: `dev.sh eval '<js expression>'`
returns the JSON value; `dev.sh snap <abs.png>` writes a PNG composite of the main
display. Read the script and devtools.rs before use.

## Proof (all in your report)

1. `node_modules/.bin/tsc -p .` in `apps/edgebar` exits 0.
2. Pixel comparison against the baselines in
   `/private/tmp/claude-501/-Users-brett-nixos-config/d8cb2a47-141a-461f-86e4-14bdf688cfa3/scratchpad/baseline/`
   (read its `README.txt` for the exact eval steps that produced each PNG). Reproduce
   each state with the same steps, snap to `.../scratchpad/scaffold/`, then
   `magick compare -metric AE -fuzz 1% <before> <after> <diff.png>`. Live data (the CPU
   pill, clock, metric numbers, a playing track) differs between any two snaps; open
   each diff image with your Read tool and confirm the only differences are in those
   regions. Report the AE numbers and what each diff shows.
3. Clicking each rail tab switches views and the notch resizes as before
   (`dev.sh eval` the clicks, snap each).
4. `cd /Users/brett/nixos-config && nix develop -c pre-commit run --all-files` passes.
5. `grep -c` shows index.html lost the notch view markup, and main.ts shrank; give
   line counts before and after.

Commit in small steps on `edgebar-notch` (Conventional Commits, `refactor(edgebar): …`,
one-to-three-sentence bodies, each ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Don't push. Leave the
notch closed when done.

Comments: only a non-obvious why, written clean (no long dashes). Moved comments keep
their meaning. UK English.

## Report (under 50 lines)

The file map after the change, where the shell landed and why, any contract change,
proof 1-5 with numbers, and anything a feature worker must know (how a widget gets
data and reports rects, the CSS import pattern).
