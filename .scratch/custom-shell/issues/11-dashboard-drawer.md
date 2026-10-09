# Dashboard drawer: calendar and media

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Super+D opens a dashboard that grows out of the frame. It has tabs, and only the tab you
are looking at is loaded (ambxst's lazy tab idea). This issue builds the drawer and its
first tab:

- **Overview tab:** date, a month calendar, and a media card for the active player
  (Quickshell's Mpris): album art, title, artist, play/pause/next/previous, and a
  position bar you can seek with.

The tab structure must make adding the performance tab (next issue) and the visualiser
straightforward.

The position bar only updates while media is playing and the dashboard is open. It must
not run any animation while paused (ambxst's progress line kept repainting when paused).

## Acceptance criteria

- [ ] Super+D opens and closes the dashboard; Escape and an outside click close it.
- [ ] The calendar shows the current month with today marked, and can move between
      months.
- [ ] With Firefox or another MPRIS player playing, the media card shows the track and the
      controls work; seeking works where the player supports it.
- [ ] With nothing playing, the media card shows an empty state.
- [ ] While closed or paused, the dashboard causes no repaints (check with the Qt scene
      graph's render statistics or GPU use).
- [ ] Switching tabs unloads tabs that are no longer shown.

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md
