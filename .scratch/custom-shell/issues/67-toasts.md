# Toasts for the shell's own news

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

One-line messages with an icon from the shell itself: charger in or out, caps lock on or
off, a new audio output, game mode on or off, a new track. Caelestia:
`modules/utilities/toasts/` (ideas only). Builds on the Drawer, PipeWire's default sink
(as `services/Osd.qml`), `UPower.onBattery`, `GameMode.on` and Mpris.

- **Not a notification:** no app sent it; no history, no actions; gone after 3 s.
- **Not the OSD:** the OSD shows one level that moves in steps (volume, microphone,
  brightness). A toast reports a change that happens once.

## Proposed choices

1. **Where: their own drawer, out of the frame's bottom-right corner,** as the pop-ups
   run into the top-right. Toasts take the pop-ups' side and the other edge, so pop-ups
   at a bottom position put them top-right; no setting. With toasts 300 px wide, the
   numbers leave 44 px to the bottom-centre OSD on the 1080-px Dell (unchecked on
   screen). Alternatives: in the pop-ups' stack; in the OSD's place, one at a time.
2. **Stacking:** at most 3, newest nearest the edge; a toast of the same kind replaces
   the old one. Like pop-ups, they wait while a drawer is open there; their time runs.
3. **Kinds:** charging (on; laptop only), caps lock (on), audio output (on, with the
   sink's description, such as "PRO X Wireless Gaming Headset Analog Stereo"), game
   mode (on), now playing (**off**: every track). The first second after start is
   ignored, as the OSD does. **Question:** does your Moonlander layout have Caps Lock?
4. **Caps lock:** Hyprland has no event for it. Use issue 40's lock-keys state: its
   `bindlni` on Caps_Lock fires `custom-shell:lockkeys`, and on release the shell reads
   the devices once, taking any keyboard's `capsLock` (the "main" one here is a mouse's
   control device, checked). Whichever issue is built first adds that state; the toast
   follows its changes, not the key, so only a real change shows.
5. **Game mode:** the `game-mode` script sends "Game mode on/off" with the
   `x-canonical-private-synchronous` hint; 7 of those sit in the saved history now
   (checked). The server turns any notification with that hint into a toast, so the
   script stays as it is for the other shells. That is game mode's toast; the shell
   adds no second one, and `toasts.gameMode` off drops it. Alternative: keep both.
6. **Quiet times:** no toasts in game mode or over a fullscreen window, except game
   mode's own. They ignore do-not-disturb: they are short and mostly answer a key.
7. **Frame shapes:** `frame/FrameShape.qml` takes 8 shapes and `FrameWindow` passes 8.
   Pass only the drawers that show (a closed one sits behind the frame). This also
   frees slots for issues 71 and 72.
8. **Settings,** under "Toasts" on the Notifications page: `toasts.charging`,
   `toasts.capsLock`, `toasts.audioOutput`, `toasts.gameMode` (`true`),
   `toasts.nowPlaying` (`false`), `toasts.timeout` (3; 1 to 10 s, step 1). **Cost:**
   nothing at rest; issue 40's one read per Caps Lock press.

## Acceptance criteria

- [ ] Turning the headset off shows one toast with the new output, bottom right, and
      adds nothing to the history.
- [ ] Caps Lock shows "Caps lock on", then "off" in its place.
- [ ] `game-mode toggle` shows a toast, not a pop-up, and no history entry.
- [ ] Pop-ups set to bottom right put toasts top right. A toast, a pop-up and the OSD
      show at once, and every drawer still opens.
- [ ] Costs nothing in game mode: no toasts but game mode's, no timers.
- [ ] Laptop (after issue 23): the charger in and out each show one.

## Blocked by

- None
