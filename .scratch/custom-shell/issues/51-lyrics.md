# Lyrics for the playing track

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Synced lyrics for the active player's track: the current line stands out, and the list
moves on as the song plays. Plain (unsynced) lyrics show as static text. Caelestia:
`plugin/src/Caelestia/Services/lyrics.cpp`, `modules/dashboard/media/LyricList.qml`
(ideas only). It builds on the media card and on the `Players` service of issue 50.

Spotify is the main player (`apps-spotify` on both hosts), and `~/Music` on
brett-desktop is empty (checked). So an online source matters most.

## Proposed choices

1. **Sources: local files first, then LRCLIB. Not NetEase.** NetEase's API is
   unofficial; Caelestia sends it a browser's User-Agent and a `Referer`, and QML's
   `XMLHttpRequest` refuses to set `Referer` (checked in Qt 6.11.2), so it would need
   curl or Rust. Alternative: LRCLIB only.
   - Local: `<lyrics.folder>/<Artist> - <Title>.lrc` (Caelestia's default folder and
     name), and for a `file://` track (`xesam:url`) the `.lrc` beside it. No recursive
     search. Read with `FileView`.
2. **Requests,** with QML's `XMLHttpRequest`, a 15 s timeout, `User-Agent:
   custom-shell`. At most two per track, and none for a cached track:
   - `https://lrclib.net/api/get?track_name=…&artist_name=…&album_name=…&duration=…`
     (seconds). Caelestia reads `syncedLyrics` and `plainLyrics` from it.
   - On a miss, once: `https://lrclib.net/api/search?track_name=…&artist_name=…`; take
     the result whose `duration` is within 2 s.
   - It waits 1 s after a track change, because metadata can arrive in parts (Caelestia
     notes mpv-mpris sends the title first).
3. **Where: a new Media tab** (`dashboard.showMedia`, default `true`): the media card
   on the left, the lyrics on the right. Alternative: a lyrics button that flips the
   Overview's card. Reason: the card has no room, and a tab exists only while it shows,
   so nothing is looked up while it is closed.
4. **Sync without polling.** Quickshell works out `position` from the last report and
   the time since, at the player's rate (checked in `player.cpp`). So one single-shot
   Timer waits for the next line's time. It is set again on a seek, pause, rate change
   or new track. The list scrolls (250 ms) only when the line changes.
5. **Cache** in `Quickshell.statePath("lyrics/")`, one JSON file per track, named by
   the `Qt.md5` of its artist, title and rounded length. A "not found" is kept too, and
   tried again after 7 days.
6. **Settings,** on the Dashboard page under a new "Media" heading: `lyrics.online`
   (default `true`; off means local files only) and `lyrics.folder` (default
   `"~/Music/Lyrics"`).
7. **Privacy:** with `lyrics.online` on, each new track's title, artist, album and
   length go to lrclib.net, but only while the Media tab shows.
8. **Cost:** no process. One timer wake per lyric line while the tab shows and the
   track plays; nothing while paused, closed or in game mode.

## Acceptance criteria

- [ ] A silent mpv playing a silent file of a well-known song's length, tagged with its
      title and artist, shows LRCLIB's synced lyrics; the line changes at each timestamp
      (log them).
- [ ] Left for the user: with Spotify, the line keeps time by eye.
- [ ] Seeking and pausing keep the line right. A track with only plain lyrics shows them.
- [ ] A local `.lrc` wins over LRCLIB. With `lyrics.online` off, nothing is sent.
- [ ] Playing a track again sends nothing (the cache). A missing track says "No lyrics".
- [ ] Closing the tab stops the timer. Costs nothing in game mode.

## Blocked by

- .scratch/custom-shell/issues/50-media-player-fuller.md
