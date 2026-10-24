# Backend: the dashboard player's media slot

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `media`.

The dashboard's FullPlayer column shows the current track even while the collapsed notch
shows something else (an OSD flash or a workspace rule outranks media there). Today
notch.rs folds media into the notch's single `NotchItem` and keeps the rest to itself.

Build, in `src-tauri/src/notch.rs` (it owns the media watcher; keep its existing
`NotchItem` behaviour unchanged):
- `MediaState` exactly as in ipc.ts, published as its own `media` event whenever any field
  changes (null when nothing is audible), plus a `media_state` command for a WebView that
  attaches late. Position changes every poll; that's fine, the payload carries no image.
- `artKey` + `media_art { key }`: the cover at player size (the FullPlayer disc is about
  128 px at 2x). For Spotify pick the 300 px image of the same cover rather than the
  64 px one the notch pill uses. For Music, try AppleScript's `raw data of artwork 1 of
  current track` written to a temp file; if that fails, `artKey` is "" for Music and say
  so. Cache a few covers by key; never refetch a key you hold.
- `album` from both players' AppleScript.
- `media_next` and `media_previous`, through the existing `transport()` helper (check
  each player's sdef for the verb: Music has `back track` as well as `previous track`).
  Don't press anything in tests; prove the verbs from the sdef files.
- For an audible app that isn't Spotify or Music, `MediaState` still names the app with
  its icon, `controls: false`, empty title fields.
