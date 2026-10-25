# Rules for every edgebar UI worker

You own your diff. Do not spawn subagents. Read first, in full:
`/Users/brett/.claude/skills/poteto-mode/SKILL.md` (Principles section included),
`/Users/brett/nixos-config/CLAUDE.md`, `/Users/brett/.claude/CLAUDE.md` (UK English
everywhere, no conjecture, pragmatic), `.scratch/edgebar-notch/PLAN.md`,
`.scratch/edgebar-notch/decisions.tsv`, `apps/edgebar/src/ipc.ts` (every command and
event, typed), `apps/edgebar/src/notch/view.ts`, `apps/edgebar/src/settings.ts`, and the
notch code as it stands (`src/notch/`, `src/main.ts`, `src/styles.css`).

## The look

edgebar now has the custom shell's look (`briefs/restyle.md`; values in
`modules/home/desktop/quickshell`): the notch opens as a drawer in the surface colour.
Build with the tokens in `styles.css :root`, never raw colours: `--surface`,
`--on-surface`, `--on-surface-variant`, `--primary`, `--on-primary`,
`--surface-container`, `--surface-container-high`, `--surface-bright`, the `--space-*`
and `--font-*` scales, `--radius-card`. Cards are `--surface-container` at
`--radius-card` with no border or shadow; buttons, chips and tabs are full-round;
`--primary` marks every active or selected state, with `--on-primary` on it. Motion comes
from `src/motion.ts`. Icons are inline Lucide SVGs (stroke 2, round caps), as elsewhere
in edgebar. ambxst (AGPL) is the reference for each widget's behaviour: ideas only, never
its code.

Performance rules (this bar is always running): nothing animates or repaints while nothing
changes; any animation loop stops when its view is hidden, the notch closes, or playback
pauses; polls run only while their view shows (start in `show`, stop in `hide`).

## Where you work, and the live app

Edit the main working tree on branch `edgebar-notch` (no worktree, no branch switch).
Brett's `pnpm tauri dev` runs this tree in herdr pane `w1:p4`: Vite hot-reloads the
WebView; saving under `src-tauri/` rebuilds and relaunches the app. Don't start another
`tauri dev`; don't run cargo against `src-tauri/target` (for a check use
`CARGO_TARGET_DIR=/Users/brett/.cache/edgebar-agent-target cargo check`). Read build
output with `herdr pane read w1:p4 --source recent --lines 60`.

Drive and see the live bar with `apps/edgebar/scripts/dev.sh eval '<js>'` and
`dev.sh snap <abs.png>` (read the script and `src-tauri/src/devtools.rs` first);
`scripts/snap-states.sh <dir>` snaps every state. Crop with `magick in.png -crop
WxH+X+Y -resize 50% out.png` before reading an image, to keep it small. Snapshots go
under `/private/tmp/claude-501/-Users-brett-nixos-config/d8cb2a47-141a-461f-86e4-14bdf688cfa3/scratchpad/<your unit>/`.
Data you can't produce on demand (a playing track, a notification, an error state):
render it by calling your widget's render function with literal data through `dev.sh
eval`, snap, then restore the live state. Check light and dark (`call set_appearance`
through eval, then back to `auto`).

## Safety on Brett's machine (hard rules)

Never turn Wi-Fi or Bluetooth off, never change network settings. Don't change media
playback, Night Shift, Focus or Caffeine in your checks except one reversible flip of
Night Shift or Caffeine to prove a toggle round-trips, put back at once. Don't change the
desktop wallpaper. Never print notification or calendar contents into your transcript or
report.

## Code shape

Each widget or view keeps its DOM, state, listeners and CSS in its own files. Use
`call`/`on` from ipc.ts. A new Rust command goes in the module that owns its domain and
gets registered in lib.rs. Settings a widget reads come from `settings.ts`; a new key gets
its default in `src-tauri/config.default.json` only. Comments only for a non-obvious why,
written clean (no long dashes).

## Proof (in your report)

1. Snapshots of each state you built (with data, empty, error or no permission, light
   and dark), each opened with your Read tool and described in a sentence.
2. Every interaction you built, exercised through `dev.sh eval` and shown working
   (a value read back, a class flipped, a snap after).
3. `node_modules/.bin/tsc -p .` exits 0; the pane shows a clean rebuild if you touched
   Rust; `nix develop -c pre-commit run --all-files` passes.
4. `grep -rn 'class="ph\|\.wip\|wip"' apps/edgebar/src apps/edgebar/index.html` shows
   none of the placeholders you replaced.

Commit in small steps on `edgebar-notch` (Conventional Commits, `feat(edgebar): …`,
short bodies, each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`).
`git add` only your own paths, never `-A`. Don't push. Leave the notch closed and the app
in `auto` appearance.

## Report (under 50 lines)

What you built per widget, design choices that differ from the brief and why, snapshot
paths, proof 1-4, and anything left undone with the reason.
