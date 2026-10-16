# Launcher terminal sessions (tmux and herdr)

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A sessions mode in the launcher. It lists the terminal multiplexer's sessions, attaches
to one in a terminal, makes a new one, renames one or ends one.

- ambxst has this for tmux as `tt`, with a preview of each session's panes
  (`modules/widgets/dashboard/tmux/TmuxTab.qml`). Ideas only.
- Both Linux hosts import `terminals-tmux` and `terminals-herdr`. tmux has resurrect and
  continuum, so the first session started also restores the last saved ones. Now,
  herdr 0.7.1's server runs with its `default` session, and no tmux server runs. sesh
  is only on the Macs.
- herdr's command line has `session list --json`, `session attach <name>`,
  `session stop <name>`, `session delete <name>`, and `--session <name>` to start one.
  It has no session rename (its workspaces have one).
- Builds on the launcher's modes and the row options of issue 47.

## Proposed choices

1. **tmux and herdr in one list.** Each row says which, with tmux's window count and
   whether a client is attached, or herdr's running or stopped. Setting
   `sessions.show`: `both`, `tmux` or `herdr`. Alternative: tmux only, as the gaps
   entry says. Reason: herdr is the one in use today.
2. **Prefix `tt`** (ambxst's), setting `launcher.sessionsPrefix`. Alternative: `$`.
3. **Enter attaches in a new terminal**: `launcher.terminal` plus
   `tmux attach -t <name>`, or plus `herdr session attach <name>` (plain `herdr` for
   `default`). A session attached elsewhere gets a second client. Alternative: focus
   the window that already shows it, which needs clients matched to windows.
4. **A name that no session has offers "New tmux session" and "New herdr session"**
   (`tmux new-session -A -s <name>`, `herdr --session <name>`), started in the home
   folder and attached. Reason: the same field finds and makes.
5. **Rename and end through the row options (issue 47).** tmux gets Rename, which asks
   for the new name (`tmux rename-session`), and Kill (`tmux kill-session`). herdr gets
   Stop and, for a stopped session, Delete. Kill, Stop and Delete wait for a second
   Enter, as they end the programs inside.
- Both settings go on the Launcher page. What `herdr session delete` removes is
  unchecked beyond its help text: read it before building Delete.
- Cost: one `tmux list-sessions -F …` and one `herdr session list --json` when the mode
  opens. No polling, so nothing in game mode. tmux's "no server running" (or "error
  connecting") gives an empty list, not an error.

## Acceptance criteria

- [ ] `tt` lists the tmux and herdr sessions, and typing filters them by name.
- [ ] Enter opens kitty attached to the chosen session.
- [ ] A new name makes a session and attaches to it.
- [ ] Rename changes a tmux session's name. Kill and Stop ask twice, then end it.
- [ ] With no sessions at all, the mode shows a hint row.
- [ ] Tests use their own tmux folder (`TMUX_TMPDIR`) and a throwaway herdr session,
      never the user's sessions.
- [ ] The apps placeholder, or issue 44's prefix list, names the prefix.

## Blocked by

- .scratch/custom-shell/issues/47-per-app-actions.md
