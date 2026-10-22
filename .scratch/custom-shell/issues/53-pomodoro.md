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

- [x] With the work time at 1 minute (from the settings), a session runs work, then a
      break, then a long break after the set count. Each end sends one notification.
- [x] Pause and resume keep the time left. Stop removes the bar entry.
- [x] `toggle-shell restart` during a session keeps its phase and end time (checked by
      stopping and starting the shell under `qs-test`, whose `toggle-shell` is a stub).
- [x] The label repaints once a minute (Qt's render log, as in issue 11).
- [ ] Sound tests go to a null sink. No sound plays in game mode or do not disturb. (No
      sound in game mode or do not disturb is checked; `pw-play` itself never ran.)
- [x] Costs nothing in game mode beyond the single-shot Timer.

## Blocked by

- None. The IPC target waits on .scratch/custom-shell/issues/34-ipc.md.

## Comments

**2026-10-19:** All nine choices approved as proposed, on the review page.

**2026-10-22:** Built as approved (commit `custom-shell: pomodoro timer in the bar, with
launcher actions and IPC`). Status is ready-for-human: the real `pw-play` has not played
the alarm, and the rebuilt desktop shell has not run it. Everything below was checked
headless with `qs-test` (work 1 minute, break 1, long break 1, long break every 2, from
`settings.json`), with `pw-play` as a stub that logs its arguments.

- Work, break, work, long break, work. With auto-start on, the saved phase read
  `work,0` then `break,1`, `work,1`, `longBreak,0` (the count resets at the long
  break), `work,0`, a minute apart (each end within 1 ms of its `endsAt`, except the last, 0.8 s
  late with six shells running). Four notifications in
  the history, from `notifications.json`: `Break: 1 minute`, `Work: 1 minute`, `Long
  break: 1 minute`, `Work: 1 minute`.
- Sound: `do not disturb` on during the third phase and game mode on (state file `on`)
  during the fourth: the stub logged two `pw-play` calls, at the first two ends, and none
  at the others. Each call had the store path of `alarm-clock-elapsed.oga`. With
  `pomodoro.sound` false, a phase end logged none. The notification still came in each
  case. Skipping sends no notification.
- Pause and resume: `pomodoro pause` after 1.0 s of a 25-minute work phase saved
  `pausedLeft` 1498960 ms and `endsAt` 0; `start` set a new `endsAt` of now plus that.
- Clicks on the bar entry, with a virtual pointer (wlr-virtual-pointer, as the notes
  describe): left click saved `endsAt` 0 and `pausedLeft` 1497526; a second left click
  ran it again; a right click saved `idle`. Screenshots of the bar (grim, headless): no entry
  after `pomodoro stop`; the timer glyph and `25 min` while work runs; the coffee cup and
  `5 min` in a break; a pause glyph when paused; a play glyph and `5 min` when a break
  waits for a click; and on a left-edge bar the play glyph over `5m`, under the clock's date.
- Restart: with the shell killed and started again 3 s later, the saved phase and
  `endsAt` were the same (`1792707852644`) and the phase still ended at that time, with
  a notification. With auto-start off the break then waited (`break`, `waiting` true,
  `endsAt` 0, `pausedLeft` 300000 or 60000) and stayed so 10 s later. A running break
  whose end passed while the shell was down (killed for 68 s) fired at once on start:
  `work` waiting, a notification and a sound.
- Repaints, Qt's render log (`qt.scenegraph.time.renderloop`) over 125 s, from 5 s after
  the session started, in four shells at once: no session 2 frames (the bar clock's two
  minutes), paused 2, running 4, and running in game mode 0. The running shell's extra 2
  match the label's minute changes, at 24 and 23 minutes. In game mode a copy that logged each label Timer
  trigger showed only the start tick (at the second the session began) and none across a
  minute boundary 75 s later; without game mode the tick at the minute came as well.
- `custom-shell` lists a `pomodoro` target with `start`, `pause`, `skip` and `stop`
  (`qs ipc show`); an unknown function or an argument is refused as for the others.
  `pomodoro skip` went from a waiting break to a running work, and from a paused work to
  a long break (the second work counted).
- Launcher actions: a copy of the shell that logged the titles showed `Start pomodoro` with
  no session; `Pause pomodoro`, `Skip to the next phase` and `Stop pomodoro` while one
  runs; `Start pomodoro` in place of Pause while paused (its subtitle `Carry on` is in
  the code, not seen). I did not
  type in the launcher: `wtype` reached no field headless.
- The settings' Bar page shows the Pomodoro section (screenshot, headless), and each
  slider's range is the schema's.
- `nix develop -c pre-commit run --all-files` passes, and brett-desktop's home builds
  (`qs-test --check` included). The built `qs-test` logs a `pw-play` call with the alarm
  path and never runs the real one; the built `toggle-shell` and `qs-dev` export the
  path.

Found: `JsonAdapter` with `onAdapterUpdated: writeAdapter()` loses values when several
properties are set one after another (the second write waits for the first, which reads
its file back over the properties, so a property just set reads its old value). Pomodoro
keeps its state in plain properties and saves one `var`. Written up in
`docs/quickshell-notes.md`.

Beyond the approved text, and why:

- The alarm path reaches the shell as `CUSTOM_SHELL_ALARM_SOUND`, set where
  `toggle-shell`, `qs-dev` and `qs-test` set their environment (`custom-shell.nix`). The
  shell has no other way to learn a store path, and naming `pkgs.sound-theme-freedesktop`
  there installs it with the shell, which answers "what installs it is unchecked".
  `qs-test` stubs `pw-play` so no test makes a sound.
- Skip starts the next phase running at once (not waiting for a click), with no
  notification or sound, and counts a skipped work session that had started (running or
  paused) as done. Skipping a phase that was still waiting does not count it.
- The launcher lists only the actions that apply: Start (or carry on) when it does not
  run, Pause while it does, Skip and Stop while a session exists. `pomodoro start` also
  carries on a paused phase; `pause`, `skip` and `stop` do nothing when they do not
  apply.
- The notification has a body, `Click the timer in the bar to start`, when the next phase
  waits.
- A phase that waits shows a play glyph, a paused one a pause glyph, and a break a coffee
  cup. A side bar shows `25m` for `25 min`, to fit its width.
- The phase end notification and the sound come from `notify-send` and `pw-play` on the
  shell's `PATH`, as approved. A phase whose end passes while the machine sleeps ends
  when the machine wakes and the single-shot Timer (a monotonic clock) next fires, which
  may be late. I did not test suspend.
- With more than one screen, each bar has its own label Timer; they are in step.

Still to check, on the desktop after the rebuild:

1. `custom-shell pomodoro start`: `25 min` and a timer icon appear to the right of the
   clock on every bar. Left-click pauses it (pause icon, same minutes), left-click again
   resumes, right-click removes it.
2. Sound, which I could not check: Settings, Bar, Pomodoro, Work 1 min, Auto-start off,
   Sound on; game mode and do not disturb off. `custom-shell pomodoro start`. After a
   minute a `Break: 5 minutes` notification should appear and the alarm should play on
   your default output. Then `custom-shell notifications setDnd
   true`, click the timer to start the break, `custom-shell pomodoro skip`, and wait for
   the work phase to end: the notification goes to the history and nothing plays. Reset
   Work with the button beside it, and `custom-shell notifications setDnd false`.
3. `toggle-shell restart` with a session running: the entry comes back with the same
   minutes.
4. Question: is the sound's volume right at the default output level, or do you want a
   volume setting (it plays at full level, as `pw-play` does by default)?
5. Question: should skipping start the next phase straight away, as built, or wait for a
   click like a phase that ended by itself?

When 1 to 3 hold, set the status to done.
