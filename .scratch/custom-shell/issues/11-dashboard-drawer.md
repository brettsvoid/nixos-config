# Dashboard drawer: calendar and media

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop with a silent mpv (`--ao=null`, the
mpv-mpris script) playing a tagged three-minute tone.
- `dashboard/Dashboard.qml`: a Drawer from the top edge (Super+D, beside Caelestia's
  bind). Tabs are entries in `tabs` with a Component each; one Loader shows the current
  tab, so leaving a tab destroys it. Tab cycles tabs. A temporary second tab with
  creation logs showed: overview created, destroyed on switching, probe created,
  destroyed on switching back, and the overview destroyed when the dashboard closed.
- Overview: the date, and a Monday-first month calendar (`Calendar.qml`, ours) with
  today marked and arrows between months (checked: October → November → September).
  `MediaCard.qml` picks the playing MPRIS player, else the first; shows cover (or a
  placeholder), title, artist, previous/play-pause/next (dimmed when the player cannot)
  and a position bar. Clicking the bar's middle seeked to 1:30 (mpv's Position
  90.5 s); the button paused it. With nothing playing it says so.
- Repaints, counted with Qt's render log over 5 s: open and paused 0, closed and paused
  0, closed and playing 0, open and playing 5 (MPRIS sends no position as it moves, so
  the card asks once a second, only while playing and only while it exists).
