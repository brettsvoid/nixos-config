# Notifications: drag to dismiss, expand, copy

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Three ways to handle a notification card, in the pop-ups and in the history: drag it
away, expand it to read all of it, copy its text. Caelestia,
`modules/notifications/Notification.qml`: drag on X dismisses, drag on Y expands, middle
click closes, a copy button. ambxst, `modules/notifications/`: drag past 70 px
dismisses, right click expands, middle click closes. Ideas only.

Today (`notifications/NotificationCard.qml`, issues 08 and 31) a click runs the default
action; × hides a pop-up, or dismisses a history entry; hover pauses the timeout. The
body shows at most `notifications.popupBodyLines` (4) lines in a pop-up, 8 in the
history; the summary at most 2.

## Proposed choices

1. **Drag sideways, either way, to dismiss.** Past a third of the card's width, or a
   fast flick, it slides away; short of that it springs back (`components/Spring.qml`).
   It then does what × does there: a pop-up hides and stays in the history; a history
   entry goes for good. Alternative: only towards the screen edge.
2. **A drag never runs the default action,** and pauses the timeout. A `DragHandler`
   on X beside the card's `MouseArea`.
3. **Middle click dismisses for good,** in both places, as Caelestia and ambxst do.
4. **Expand with a chevron** beside ×, shown only when the summary or body is cut
   (`Text.truncated`); right click toggles too. Expanded, the body shows up to 20 lines.
   The drawer already eases its size. Alternative: Caelestia's vertical drag. Reason: a
   chevron can be seen; a gesture cannot.
5. **An expanded pop-up stays** until closed or collapsed. Alternative: its timeout
   runs again once the pointer leaves.
6. **Copy:** a button beside the chevron, shown while the pointer is on the card. It
   copies the summary and body as plain text: tags (`b`, `i`, `u`, `a`, `img`) removed,
   `&amp;` `&lt;` `&gt;` `&quot;` `&apos;` decoded, one `wl-copy` as
   `launcher/CalculatorMode.qml` uses. The icon shows a tick for 2 s. Restored entries
   (issue 31) copy too. Alternative: the body only (Caelestia).
7. **No new settings:** always on; `notifications.popupBodyLines` stays the collapsed
   limit.
8. **Cost:** nothing at rest; animation only while dragging or resizing; the tick's
   timer only after a copy. Game mode changes nothing (pop-ups wait in the history).

## Acceptance criteria

- [ ] Dragging a pop-up past a third of its width hides it; it is still in the history.
- [ ] A short drag springs back; a click runs the default action; a drag never does.
- [ ] In the history, a drag or a middle click removes the entry, also after a restart.
- [ ] A 15-line body shows the chevron, expands in full, and stays until closed. A
      1-line body has no chevron.
- [ ] Copying `notify-send 'A & B' '<b>bold</b> &amp; <a href="x">link</a>'` gives
      `A & B` and `bold & link` on two lines.
- [ ] A drag past the drawer's edge keeps tracking (unchecked: the press's implicit
      grab should hold it outside the input mask).
- [ ] Nothing redraws while no card moves.

## Blocked by

- None (issues 08 and 31 are done)
