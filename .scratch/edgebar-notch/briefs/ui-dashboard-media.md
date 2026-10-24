# UI: the dashboard's player column and control rail

Read `briefs/_ui-common.md` first; its rules apply. Unit name: `ui-media`. You replace
`src/notch/dashboard/player.ts` and `controls.ts` (and their CSS). The backend is merged:
`media_state`, the `media` event, `media_art`, `media_toggle`, `media_next`,
`media_previous`, `media_seek` (see ipc.ts and `src-tauri/src/notch.rs`).

## Player column (ambxst FullPlayer, about 200 px wide, full column height)

- Backdrop: the cover as a soft wash at about 25 % opacity across the card, plus a thin
  frame of the sharp cover around the card's edge. WebKit note from styles.css: don't put
  a CSS `filter: blur` on it (WebKit clips the layer to a square and the corners escape);
  get softness from scaling a small image up, as the collapsed notch's media pill does.
- A disc: the cover in a circle (about 120 px) that turns once every 8 s while playing and
  eases to rest on pause. Above it, the seek control as the top half of a ring around the
  disc: the played part a gentle wave in `--primary` (flat when paused), the rest a flat
  line in `--surface-bright`, a radial tick for the head with a small gap either side. Drag
  on the ring to seek, committing on release (`media_seek`), as the collapsed notch's
  playhead does. Disabled when `controls` is false or `duration` is 0.
- Title 16 px bold, one line; album and artist 13-14 px dimmer, one line each; long text
  marquees the way the collapsed notch's lines do (there's a `setLine` helper in main.ts:
  share it rather than copy it).
- Transport row: the source app's icon, previous, play/pause (44 px `--primary` circle,
  becoming a rounded square while playing), next. Then "m:ss / m:ss" 12 px dim, ticking
  each second from `position` while playing.
- Nothing playing: "Nothing playing" with the controls dimmed and disabled; an audible app
  that isn't Spotify or Music shows its name and icon with the transport disabled.
- No animation runs while paused, hidden or closed (see the performance rules).

## Control rail (48 px column: brightness over volume and mic)

- Brightness: a tall vertical slider filling the rail above the dials: a 4 px track,
  `--primary` below the handle and `--surface-bright` above it, a short horizontal handle;
  press jumps to the pointer and drag follows; the wheel steps 5 %; a small "NN%" label
  beside the handle only while dragging. `get_brightness`/`set_brightness` (built-in
  display only: if `get_brightness` fails or there's no built-in display, show it disabled
  with a tooltip saying so).
- Volume and mic dials: 48 px tiles, a 270° arc open at the bottom (4 px stroke, round
  caps), progress `--primary`, remainder `--surface-bright`, a short radial tick for the
  value, the icon in the middle. Vertical drag changes the value (100 px = full range),
  the wheel steps 5 %, a click mutes and unmutes. `get_volume`, `set_volume`,
  `set_input_volume` exist; mute does not: add it in Rust next to them (osascript `output
  muted` for the speaker; for the mic, remember the level and set 0 / restore), and add
  the commands to ipc.ts. A muted dial draws its progress in `--surface-bright`.
- Setting volume, mic or brightness already flashes the collapsed notch's OSD; keep that.
- Read the current values on `show`; the popup in the bar's controls drawer edits the same
  values, so re-read when the dashboard shows rather than caching.

Prove the player with live data if something is playing (SonoBus is usually audible but
has no controls), and with literal `MediaState` data rendered through eval for the
Spotify case and the empty case. Don't press play, next or previous on Brett's players;
exercise the buttons with a literal state and show they call the right command by
wrapping `call` in a recorder through eval.
