# Fuller media player: shuffle, loop and a choice of player

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

The dashboard's media card (`dashboard/MediaCard.qml`) has cover art, title, artist,
previous / play-pause / next (`components/MediaControls.qml`) and a seek bar. It picks
the playing player, else the first. Add shuffle, loop, and a way to choose the player.
Caelestia: `modules/dashboard/media/Details.qml`, `services/Players.qml`; ambxst:
`FullPlayer.qml` (ideas only).

Quickshell's `MprisPlayer` has what this needs (checked in its `player.hpp`):
`shuffle` and `shuffleSupported`; `loopState` (`MprisLoopState.None`, `Track`,
`Playlist`) and `loopSupported`; both writable only when `canControl`. Its `identity`
names the player. mpv-mpris has both properties read-write (checked in its `mpris.c`),
so a silent mpv can test them.

## Proposed choices

1. **Shuffle at the far left of the controls, loop at the far right.** MediaControls
   gets a property for the two extra buttons; the lock screen keeps three. Alternative:
   a second row under the seek bar. Reason: one row keeps the card's height.
2. **A button hides when the player lacks it** (`shuffleSupported`, `loopSupported`)
   and dims when `canControl` is false. Alternative: always shown, dimmed. Reason: a
   browser tab would carry two dead buttons.
3. **Loop cycles None → Playlist → Track,** with md-repeat_off, md-repeat and
   md-repeat_once. Alternative: Caelestia's None → Track → Playlist. Reason: repeating
   the whole list is the more common wish, so it comes first.
4. **Choosing a player: with two or more, the player's name becomes a button.** It opens
   a short list in the card: each player's name and track. Alternative: a click moves
   to the next player. Reason: the list shows which is which.
5. **One `services/Players.qml` singleton** decides the active player, for the media
   card and the lock screen (`lock/LockMedia.qml`), and later toasts and IPC:
   - a player chosen by hand, while it exists;
   - else `media.preferredPlayer` (by `identity`, e.g. `"Spotify"`; default `""`), while
     it plays, which settles two playing at once;
   - else the player that last played (LockMedia's rule), else the first.
   Alternative: keep today's rule (the playing one, else the first). Reason: the card
   no longer jumps to another player when you pause.
6. **Settings:** `media.preferredPlayer`, as a text row on the Dashboard page's Overview
   section.
7. **Media keys follow `Players`:** `GlobalShortcut`s `custom-shell:mediaPlayPause`,
   `mediaNext` and `mediaPrevious` (as `services/Osd.qml` has one), bound with `global`
   in `hyprland.nix`, so no process per key (issue 34's advice). Issue 34's `media`
   target uses `Players` too. Alternative: keep playerctl (issue 34's plan), which works
   under any shell but picks its own player (unchecked which).
8. **Cost:** no new timer or process. The 1 s position timer stays as it is.

## Acceptance criteria

- [ ] With a silent mpv (`--ao=null`, mpv-mpris; neither is installed, so bring them in
      for the test as issue 11 did) playing, shuffle and loop show, change mpv's state,
      and follow changes made in mpv.
- [ ] With Firefox playing a video, the buttons hide or dim as the player reports.
- [ ] With mpv and Firefox both open, the list shows both; the choice holds until that
      player quits, and the lock screen shows the same player.
- [ ] Pausing the active player keeps it on the card. The media keys act on it.
- [ ] `media.preferredPlayer` works from the settings window and from Nix.
- [ ] Nothing new runs while the dashboard is closed or in game mode.

## Blocked by

- None.

## Comments

**2026-10-19:** Choice 3 agreed on the review page. No verdict on the issue yet.
