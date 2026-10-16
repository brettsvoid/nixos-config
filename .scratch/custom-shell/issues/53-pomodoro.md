# Pomodoro timer

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A work and break timer. Work for 25 minutes, break for 5, and take a long break after
every fourth work session. ambxst has one in its bar clock's pop-up
(`modules/bar/clock/Pomodoro.qml`: times, auto-start, an alarm sound, `notify-send`;
ideas only).

- A `services/Pomodoro.qml` singleton holds the phase (`idle`, `work`, `break`,
  `longBreak`), the end time, the time left while paused, and the work sessions done.
  It saves them in `Quickshell.statePath("pomodoro.json")`, so a shell restart (a
  rebuild) keeps a running timer.
- The phase end is one single-shot Timer set to the end time. Nothing ticks for it.

## Proposed choices

1. **Where: a bar entry beside the clock, only while a session exists.** It shows an
   icon and the minutes left ("18 min"). A click pauses or resumes, or starts the next
   phase when it waits; a right-click stops. Alternatives: a dashboard card, or a clock
   pop-out if issue 37 adds one. Reason: the time left stays in sight while you work.
2. **Minutes only, rounded up.** A Timer set to the next whole minute of time left
   updates the label, so it repaints once a minute. It runs only while the entry is
   visible, as the bar clock's `SystemClock` does. Alternative: minutes and seconds,
   which repaints every second.
3. **Start from the launcher's actions:** "Start pomodoro", "Pause pomodoro", "Skip to
   the next phase", "Stop pomodoro". With IPC (issue 34), a `pomodoro` target with the
   same four.
4. **At each phase end, a notification** through `notify-send -a Pomodoro` (on PATH;
   libnotify stays after issue 23), for example "Break: 5 minutes". The shell's own
   rules apply: held in the history in game mode or do not disturb.
5. **And a sound,** `pw-play` of `alarm-clock-elapsed.oga` from
   `pkgs.sound-theme-freedesktop` (0.8; CC-BY and GPL-2.0 sounds), by store path. It is
   on brett-desktop today, but what installs it is unchecked. No sound in game mode or
   do not disturb. Alternative: no sound.
6. **The next phase waits for a click** (`pomodoro.autoStart`, default `false`).
   Reason: a break that starts by itself is easy to miss.
7. **In game mode it keeps running.** The bar is hidden, so its label timer stops; the
   phase-end Timer costs nothing. Alternative: pause it while game mode is on.
8. **Settings,** under a new "Pomodoro" heading on the Bar page:
   `pomodoro.workMinutes` (25; 1 to 90), `pomodoro.breakMinutes` (5; 1 to 30),
   `pomodoro.longBreakMinutes` (15; 1 to 60), `pomodoro.longBreakEvery` (4; 0 to 8, 0 is
   never), `pomodoro.autoStart` (`false`), `pomodoro.sound` (`true`). All step 1.
9. **Cost:** with no session, nothing. With one, a label repaint a minute, and one
   `notify-send` and one `pw-play` at each phase end.

## Acceptance criteria

- [ ] With the work time at 1 minute (from the settings), a session runs work, then a
      break, then a long break after the set count. Each end sends one notification.
- [ ] Pause and resume keep the time left. Stop removes the bar entry.
- [ ] `toggle-shell restart` during a session keeps its phase and end time.
- [ ] The label repaints once a minute (Qt's render log, as in issue 11).
- [ ] Sound tests go to a null sink. No sound plays in game mode or do not disturb.
- [ ] Costs nothing in game mode beyond the single-shot Timer.

## Blocked by

- None. The IPC target waits on .scratch/custom-shell/issues/34-ipc.md.
